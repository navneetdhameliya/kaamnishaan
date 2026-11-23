import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kaamnishaan/UI/screens/team_section/invite_section/invite_controller.dart';
import 'package:kaamnishaan/UI/screens/team_section/team_member_section/team_member_controller.dart';
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

  group('Team member page', () {
    const ramesh = MemberOutModel(id: 'u1', name: 'Ramesh Patel', role: 'technician', status: 'active', phone: '+919812345678');
    final detail = MemberOutModel(
      id: 'u1', name: 'Ramesh Patel', role: 'technician', status: 'active', phone: '+919812345678',
      waitingJobs: 2, activeJobs: 1, doneJobs30d: 14, joinedAt: DateTime(2026, 11, 3),
    );
    final asked = <String>[];
    var answer = true;

    TeamMemberController open(MemberOutModel m, {bool owner = false}) {
      session.me.value = MeOutModel(
        id: 'u9', name: 'Priya Mehta', emailVerified: true, appLanguage: 'en', theme: 'system', company: company,
        role: owner ? 'owner' : 'manager',
        permissions: owner ? const ['team.manage_managers', 'team.invite_technician'] : const ['team.invite_technician'],
      );
      when(() => repo.member(any())).thenAnswer((i) async => ApiSuccess<MemberOutModel>(
            i.positionalArguments.first == 'u1' ? detail : m,
          ));
      return TeamMemberController(
        company: repo,
        session: session,
        member: m,
        openUrl: (_) async => true,
        confirm: ({required title, required body, required action}) async {
          asked.add('$title | $body');
          return answer;
        },
      );
    }

    setUp(() {
      asked.clear();
      answer = true;
    });

    test('shows the jobs and what a manager may do with a technician', () async {
      final c = open(ramesh);
      await c.load();
      expect((c.waitingJobs, c.activeJobs, c.doneJobs, c.showJobs), (2, 1, 14, true));
      expect(c.since, 'Joined 3 Nov 2026');
      expect((c.canCall, c.canRemove, c.canChangeRole), (true, true, false)); // managers can't make managers
      expect(c.removeBody, startsWith('Their 2 jobs not started go back to Unassigned'));
    });

    test('removing asks first, says what happens to the jobs, then goes back', () async {
      when(() => repo.removeMember(any())).thenAnswer((_) async => const ApiSuccess<void>(null));
      final c = open(ramesh);
      await c.load();
      answer = false;
      await c.onRemoveTap();
      verifyNever(() => repo.removeMember(any()));
      expect(asked.single, startsWith('Remove Ramesh from the team? | Their 2 jobs'));
      answer = true;
      await _ignoreApp(c.onRemoveTap);
      verify(() => repo.removeMember('u1')).called(1);
      expect(c.busy.value, isNull);
    });

    test('the owner changes roles; nobody changes themselves or the owner', () async {
      when(() => repo.setRole(any(), any())).thenAnswer(
        (_) async => const ApiSuccess<MemberOutModel>(
          MemberOutModel(id: 'u1', name: 'Ramesh Patel', role: 'manager', status: 'active', phone: '+919812345678'),
        ),
      );
      final c = open(ramesh, owner: true);
      await c.load();
      expect((c.canChangeRole, c.roleAction), (true, 'Make manager'));
      await _ignoreApp(c.onRoleTap);
      verify(() => repo.setRole('u1', 'manager')).called(1);
      expect(asked.single, startsWith('Make Ramesh a manager?'));

      final me = open(const MemberOutModel(id: 'u9', name: 'Priya Mehta', role: 'owner', status: 'active'), owner: true);
      expect((me.isMe, me.canRemove, me.canChangeRole, me.canCall), (true, false, false, false));
      final boss = open(const MemberOutModel(id: 'u7', name: 'Asha Patel', role: 'owner', status: 'active'));
      expect((boss.canRemove, boss.canChangeRole), (false, false));
      final otherManager = open(const MemberOutModel(id: 'u8', name: 'Neha Shah', role: 'manager', status: 'active'));
      expect((otherManager.canRemove, otherManager.canChangeRole), (false, false)); // only the owner
    });

    test('someone not joined yet: resend or cancel the invite', () async {
      when(() => repo.cancelInvite(any())).thenAnswer((_) async => const ApiSuccess<void>(null));
      final arjun = MemberOutModel(
        id: 'u3', name: 'Arjun Desai', role: 'technician', status: 'invited', inviteId: 'i3',
        invitedAt: DateTime.now().subtract(const Duration(days: 2)),
      );
      final c = open(arjun);
      await c.load();
      expect((c.invited, c.canHandleInvite, c.canRemove, c.showJobs, c.state), (true, true, false, false, 'Waiting to join'));
      await _ignoreApp(c.onCancelInviteTap);
      verify(() => repo.cancelInvite('i3')).called(1);
    });
  });
}
