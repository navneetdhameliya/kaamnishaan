import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kaamnishaan/UI/screens/customer_section/customer_details_section/customer_details_controller.dart';
import 'package:kaamnishaan/UI/screens/me_section/company_settings_section/company_settings_controller.dart';
import 'package:kaamnishaan/infrastructure/data_access_layer/networks/api_result.dart';
import 'package:kaamnishaan/infrastructure/lang/translation_service.dart';
import 'package:kaamnishaan/infrastructure/lang/translations.g.dart';
import 'package:kaamnishaan/infrastructure/models/api_models.g.dart';
import 'package:kaamnishaan/infrastructure/services/config_service.dart';
import 'package:kaamnishaan/infrastructure/services/preferences_service.dart';
import 'package:kaamnishaan/infrastructure/services/session_service.dart';
import 'package:kaamnishaan/infrastructure/shared/job_arguments.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fakes.dart';

/// Toasts need the app, which unit tests don't have.
Future<void> _ignoreApp(Future<void> Function() run) async {
  try {
    await run();
  } on Object catch (_) {}
}

final clinic = CustomerOutModel(
  id: 'c1',
  name: 'Green Valley Clinic',
  customerSince: DateTime(2024, 3, 2),
  jobCount: 5,
  contacts: const [
    ContactOutModel(id: 'k2', name: 'Front desk', isPrimary: false, reviewOptedOut: false, phone: '+15550100000'),
    ContactOutModel(
      id: 'k1', name: 'Dr. Anita Rao', title: 'Clinic owner', isPrimary: true, reviewOptedOut: false,
      phone: '+1 555 010 0444', email: 'office@greenvalley.example',
    ),
  ],
  sites: const [SiteOutModel(id: 's1', addressLine1: '4 Lake Road', city: 'Springfield', country: 'US', lat: 39.8, lng: -89.6)],
  updatedAt: DateTime(2026, 10, 31),
  version: 1,
);

CompanyOutModel company({String plan = 'professional', bool share = true, String? phone}) => CompanyOutModel(
      id: 'c1',
      name: 'BrightAir Services',
      trade: 'hvac',
      country: 'IN',
      timezone: 'Asia/Kolkata',
      currency: 'INR',
      reportLanguage: 'en',
      plan: plan,
      status: 'trial',
      trialEndsAt: DateTime(2026, 12, 1, 12),
      settings: CompanySettingsModel(techniciansCanShare: share, contactPhone: phone),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late TranslationService translation;
  late SessionService session;

  setUpAll(() async => initializeDateFormatting());

  setUp(() async {
    Get.reset();
    Get.testMode = true;
    Get.addTranslations(KnTranslations().keys);
    Get.locale = const Locale('en', 'IN');
    SharedPreferences.setMockInitialValues({});
    translation = TranslationService(await PreferencesService.create());
    session = SessionService(tokens: MemoryTokenStorage(), repository: MockAuthRepository());
  });

  test('M18: the main contact, newest jobs first, and call / email / map', () async {
    final repo = MockCustomersRepository();
    when(() => repo.customer(any())).thenAnswer((_) async => ApiSuccess<CustomerOutModel>(clinic));
    when(() => repo.jobs(any())).thenAnswer(
      (_) async => ApiSuccess<JobListModel>(
        JobListModel(
          data: [
            job(id: 'a', title: 'Outdoor AC service', status: 'completed', at: DateTime(2026, 5, 3)),
            job(id: 'b', title: 'Filter change', status: 'completed', at: DateTime(2026, 8, 12)),
            job(id: 'c', title: 'Gas refill', status: 'completed', at: DateTime(2026, 1, 9)),
          ],
          meta: const ListMetaModel(),
        ),
      ),
    );
    final opened = <Uri>[];
    final c = CustomerDetailsController(
      customers: repo,
      translation: translation,
      args: const CustomerArguments(id: 'c1', name: 'Green Valley Clinic'),
      open: (u) async {
        opened.add(u);
        return true;
      },
    );
    await c.load();
    expect(c.since, 'Customer since 2024 · 5 jobs');
    expect((c.contactName, c.contactInitials, c.contactLine), ('Dr. Anita Rao', 'AR', 'Clinic owner · main contact'));
    expect(c.address, '4 Lake Road, Springfield');
    expect(c.shownJobs.map((j) => j.title), ['Filter change', 'Outdoor AC service']);
    expect(c.jobLine(c.shownJobs.first), '12 Aug · Not assigned');
    expect(c.seeAllText, 'See all 3');
    c.onSeeAllTap();
    expect((c.shownJobs.length, c.seeAllText), (3, 'Show less'));
    await c.onCallTap();
    await c.onEmailTap();
    await c.onMapTap();
    expect(opened.map((u) => u.toString()), [
      'tel:+15550100444',
      'mailto:office@greenvalley.example',
      'https://www.google.com/maps/search/?api=1&query=39.8%2C-89.6',
    ]);
  });

  group('M39 company settings', () {
    late MockCompanyRepository repo;

    CompanySettingsController open(String role) {
      repo = MockCompanyRepository();
      session.me.value = MeOutModel(
        id: 'u9', name: 'Priya Mehta', emailVerified: true, appLanguage: 'en', theme: 'system', role: role,
        company: company(), permissions: const [],
      );
      when(() => repo.plans(currency: any(named: 'currency'), locale: any(named: 'locale'))).thenAnswer(
        (_) async => const ApiSuccess<PlansOutModel>(
          PlansOutModel(
            currency: 'INR',
            trialDays: 14,
            creditPacks: [],
            creditRules: CreditRulesModel(),
            plans: [
              PlanOutModel(
                code: 'professional', name: 'Professional', price: MoneyModel(amount: 129900, currency: 'INR'),
                features: [], mostPopular: true,
              ),
            ],
          ),
        ),
      );
      return CompanySettingsController(
        companies: repo,
        files: MockFilesRepository(),
        session: session,
        config: ConfigService(MockConfigRepository()),
        picker: FakeImagePicker(),
        translation: translation,
      );
    }

    test('shows the plan and lets the owner switch technician sharing off', () async {
      final c = open('owner');
      await c.loadPlan();
      expect(c.planValue.replaceAll('\u2060', ''), 'Professional · ₹1,299/mo');
      expect(c.planLine, 'Trial ends 1 Dec');
      expect(c.techniciansCanShare, isTrue);
      when(() => repo.setTechniciansCanShare(any())).thenAnswer(
        (_) async => ApiSuccess<CompanyOutModel>(company(share: false)),
      );
      await _ignoreApp(() => c.onShareChanged(false));
      verify(() => repo.setTechniciansCanShare(false)).called(1);
      expect(c.techniciansCanShare, isFalse); // the session has the new company
    });

    test('the owner sets the phone customers see as Call on their report', () async {
      final c = open('owner');
      expect(c.contactPhone, '');
      expect(c.onPhoneTap(), isTrue);
      c.phoneBox.text = ' +91 98250 22222 ';
      when(() => repo.setContactPhone(any())).thenAnswer(
        (_) async => ApiSuccess<CompanyOutModel>(company(phone: '+91 98250 22222')),
      );
      await _ignoreApp(c.onPhoneSave);
      verify(() => repo.setContactPhone('+91 98250 22222')).called(1);
      expect(c.contactPhone, '+91 98250 22222');
      expect(c.onPhoneTap() && c.phoneBox.text == '+91 98250 22222', isTrue); // opens with the number as it is
      c.onClose();
    });

    test('the owner renames the company; an empty or unchanged name sends nothing', () async {
      final c = open('owner');
      expect(c.onNameTap(), isTrue);
      expect(c.nameBox.text, c.companyName);
      c.nameBox.text = '   ';
      expect(await c.onNameSave(), isFalse);
      c.nameBox.text = c.companyName;
      expect(await c.onNameSave(), isTrue);
      verifyNever(() => repo.rename(any()));
      when(() => repo.rename(any())).thenAnswer((_) async => ApiSuccess<CompanyOutModel>(company()));
      c.nameBox.text = ' BrightAir Cooling ';
      await _ignoreApp(c.onNameSave);
      verify(() => repo.rename('BrightAir Cooling')).called(1);
      c.onClose();
    });

    test('managers can look but not change', () async {
      final c = open('manager');
      expect(c.isOwner, isFalse);
      await _ignoreApp(() => c.onShareChanged(false));
      expect(c.onTradeTapSafe(), isFalse);
      verifyNever(() => repo.setTechniciansCanShare(any()));
    });
  });
}

extension on CompanySettingsController {
  /// onTradeTap shows a toast for managers; unit tests have no app for it.
  bool onTradeTapSafe() {
    try {
      return onTradeTap();
    } on Object catch (_) {
      return false;
    }
  }
}
