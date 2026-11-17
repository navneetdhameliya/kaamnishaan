import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kaamnishaan/UI/screens/team_section/invite_section/invite_controller.dart';
import 'package:kaamnishaan/UI/screens/team_section/team_section/team_controller.dart';
import 'package:kaamnishaan/infrastructure/data_access_layer/networks/api_exception.dart';
import 'package:kaamnishaan/infrastructure/data_access_layer/networks/api_result.dart';
import 'package:kaamnishaan/infrastructure/lang/translation_service.dart';
import 'package:kaamnishaan/infrastructure/lang/translations.g.dart';
import 'package:kaamnishaan/infrastructure/models/api_models.g.dart';
import 'package:kaamnishaan/infrastructure/services/config_service.dart';
import 'package:kaamnishaan/infrastructure/services/preferences_service.dart';
import 'package:kaamnishaan/infrastructure/services/session_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fakes.dart';

/// Toasts and navigation need the app, which unit tests don't have.
Future<void> _ignoreApp(Future<void> Function() run) async {
  try {
    await run();
  } on Object catch (_) {}
}

final now = DateTime(2026, 10, 31, 12, 0);

const company = CompanyOutModel(
  id: 'c1',
  name: 'BrightAir Services',
  country: 'IN',
  timezone: 'Asia/Kolkata',
  currency: 'INR',
  reportLanguage: 'hi',
  plan: 'professional',
  status: 'trial',
  settings: CompanySettingsModel(),
);

MeOutModel me(String role) => MeOutModel(
      id: 'u9',
      name: 'Priya Mehta',
      emailVerified: true,
      appLanguage: 'en',
      theme: 'system',
      role: role,
      company: company,
      permissions: const [],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockCompanyRepository repo;
  late SessionService session;
  late TranslationService translation;

  setUpAll(() async => initializeDateFormatting());

  setUp(() async {
    Get.reset();
    Get.testMode = true;
    Get.addTranslations(KnTranslations().keys);
    Get.locale = const Locale('en', 'IN');
    SharedPreferences.setMockInitialValues({});
    translation = TranslationService(await PreferencesService.create());
    repo = MockCompanyRepository();
    session = SessionService(tokens: MemoryTokenStorage(), repository: MockAuthRepository());
    session.me.value = me('manager');
  });

  test('M40 team: counts, what each person is doing, and who is still to join', () async {
    when(() => repo.team(role: any(named: 'role'), q: any(named: 'q'))).thenAnswer(
      (_) async => ApiSuccess<MemberListModel>(
        MemberListModel(
          data: [
            const MemberOutModel(id: 'u9', name: 'Priya Mehta', role: 'manager', status: 'active'),
            const MemberOutModel(
              id: 'u1', name: 'Ramesh Patel', role: 'technician', status: 'active', liveStatus: 'on_job', jobsToday: 3,
            ),
            const MemberOutModel(
              id: 'u2', name: 'Carlos Ruiz', role: 'technician', status: 'active', liveStatus: 'idle', jobsToday: 2,
            ),
            MemberOutModel(
              id: 'u3', name: 'Arjun Desai', role: 'technician', status: 'invited', inviteId: 'i3',
              invitedAt: now.subtract(const Duration(days: 2)),
            ),
          ],
          meta: const ListMetaModel(),
        ),
      ),
    );
    final c = TeamController(company: repo, session: session, clock: () => now);
    await c.load();
    expect(c.subtitle, 'BrightAir Services · 4 people');
    expect(TeamFilter.values.map(c.chipLabel), ['All 4', 'Technicians 3', 'Managers 1']);
    final [priya, ramesh, carlos] = c.active;
    expect((c.name(priya), c.line(priya), c.state(priya)), ('Priya Mehta (you)', 'Manager', 'Online'));
    expect((c.line(ramesh), c.state(ramesh), c.tone(ramesh)), ('Technician · 3 jobs', 'On a job', MemberTone.good));
    expect((c.state(carlos), c.tone(carlos)), ('Free', MemberTone.quiet));
    final arjun = c.waiting.single;
    expect(c.line(arjun), startsWith('Technician · SMS sent 2'));
    c.onFilterTap(TeamFilter.managers);
    expect((c.active.length, c.waiting.length), (1, 0));
    c.onFilterTap(TeamFilter.all);
    c.onSearchChanged('carl');
    expect(c.active.single.name, 'Carlos Ruiz');
    when(() => repo.resendInvite(any())).thenAnswer(
      (_) async => ApiSuccess<InviteOutModel>(
        InviteOutModel(
          id: 'i4', userId: 'u3', phone: '+919898989898', name: 'Arjun Desai', role: 'technician',
          status: 'pending', expiresAt: now, smsPreview: '', link: '',
        ),
      ),
    );
    await _ignoreApp(() => c.onResendTap(arjun));
    verify(() => repo.resendInvite('i3')).called(1);
    c.onClose();
  });

  group('M40 invite', () {
    InviteController open() {
      when(() => repo.invitePreview()).thenAnswer(
        (_) async => const ApiSuccess<String>('Priya from BrightAir Services invited you to KaamNishaan.'),
      );
      return InviteController(
        company: repo,
        config: ConfigService(MockConfigRepository()),
        session: session,
        translation: translation,
        role: 'technician',
      )..onInit();
    }

    test('checks the number and name, then sends the invite', () async {
      final c = open();
      await Future<void>.delayed(Duration.zero);
      expect(c.preview.value, startsWith('Priya from BrightAir'));
      expect((c.smsLanguage.value, c.languageName), ('hi', 'हिन्दी'));
      expect(c.canInviteManager, isFalse); // managers invite technicians only
      expect(c.willGet, 'They will get this SMS');
      await c.onSendTap();
      expect(c.phoneError, 'Enter a 10-digit phone number');
      expect(c.nameError, 'Write their name');
      c.onPhoneChanged('98250 11111');
      c.onNameChanged('Arjun Desai');
      expect((c.phoneError, c.nameError, c.willGet), (null, null, 'Arjun will get this SMS'));
      when(
        () => repo.invite(
          phone: any(named: 'phone'),
          name: any(named: 'name'),
          role: any(named: 'role'),
          smsLanguage: any(named: 'smsLanguage'),
        ),
      ).thenAnswer(
        (_) async => ApiSuccess<InviteOutModel>(
          InviteOutModel(
            id: 'i1', userId: 'u3', phone: '+919825011111', name: 'Arjun Desai', role: 'technician',
            status: 'pending', expiresAt: now, smsPreview: '', link: '',
          ),
        ),
      );
      await _ignoreApp(c.onSendTap);
      verify(() => repo.invite(phone: '+919825011111', name: 'Arjun Desai', role: 'technician', smsLanguage: 'hi'))
          .called(1);
      c.onClose();
    });

    test('a number already in the team says who, and "Send invite" waits for another number', () async {
      final c = open();
      when(
        () => repo.invite(
          phone: any(named: 'phone'),
          name: any(named: 'name'),
          role: any(named: 'role'),
          smsLanguage: any(named: 'smsLanguage'),
        ),
      ).thenAnswer(
        (_) async => const ApiFailure<InviteOutModel>(
          ApiException(
            code: 'phone_in_team',
            message: 'This number is already on your team.',
            fields: {'phone': 'phone_in_team'},
            details: {
              'existing_member': {'user_id': 'u2', 'status': 'active', 'role': 'technician', 'name': 'Carlos Ruiz'},
            },
          ),
        ),
      );
      c.onPhoneChanged('5550100188');
      c.onNameChanged('Arjun Desai');
      await c.onSendTap();
      expect(c.phoneError, 'Already in your team (Carlos Ruiz).');
      expect((c.seeInTeam, c.canSend), ('See Carlos in Team', false));
      c.onPhoneChanged('5550100189');
      expect((c.phoneError, c.canSend), (null, true));
      c.onClose();
    });
  });
}
