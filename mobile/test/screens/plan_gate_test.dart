import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:kaamnishaan/infrastructure/lang/translations.g.dart';
import 'package:kaamnishaan/infrastructure/models/api_models.g.dart';
import 'package:kaamnishaan/infrastructure/services/session_service.dart';
import 'package:kaamnishaan/infrastructure/shared/plan_gate.dart';

import '../helpers/fakes.dart';

CompanyOutModel company(List<String>? features) => CompanyOutModel(
      id: 'c1',
      name: 'BrightAir Services',
      trade: 'hvac',
      country: 'IN',
      timezone: 'Asia/Kolkata',
      currency: 'INR',
      reportLanguage: 'en',
      plan: 'starter',
      status: 'active',
      settings: const CompanySettingsModel(),
      features: features,
    );

void main() {
  late SessionService session;

  setUp(() {
    Get.reset();
    Get.testMode = true;
    Get.addTranslations(KnTranslations().keys);
    Get.locale = const Locale('en', 'IN');
    session = SessionService(tokens: MemoryTokenStorage(), repository: MockAuthRepository());
  });

  void signIn(List<String>? features, {String role = 'owner'}) => session.me.value = MeOutModel(
        id: 'u1', name: 'Priya Mehta', emailVerified: true, appLanguage: 'en', theme: 'system', role: role,
        company: company(features), permissions: const [],
      );

  test('the plan decides what the app opens (D-147)', () {
    signIn(['branded_pdf']);
    expect(PlanGate.has(session, PlanFeature.brandedPdf), isTrue);
    expect(PlanGate.has(session, PlanFeature.assistant), isFalse);
    expect(PlanGate.has(session, PlanFeature.ownChecklists), isFalse);
    signIn(['ai_assistant', 'custom_checklists', 'branded_pdf']); // a trial has everything
    expect(PlanGate.check(PlanFeature.assistant, session: session), isTrue);
  });

  test('an older server that sends no features leaves the choice to the server', () {
    signIn(null);
    expect(PlanGate.has(session, PlanFeature.assistant), isTrue);
    session.me.value = null;
    expect(PlanGate.has(session, PlanFeature.assistant), isTrue);
  });
}
