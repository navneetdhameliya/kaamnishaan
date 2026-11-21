import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:kaamnishaan/UI/screens/me_section/delete_account_section/delete_account_controller.dart';
import 'package:kaamnishaan/infrastructure/data_access_layer/networks/api_exception.dart';
import 'package:kaamnishaan/infrastructure/data_access_layer/networks/api_result.dart';
import 'package:kaamnishaan/infrastructure/lang/translations.g.dart';
import 'package:kaamnishaan/infrastructure/models/api_models.g.dart';
import 'package:kaamnishaan/infrastructure/services/session_service.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/fakes.dart';

/// Toasts and navigation need the running app; the state changes before them.
Future<void> _ignoreApp(Future<void> Function() run) async {
  try {
    await run();
  } on Object catch (_) {}
}

const owner = MeOutModel(
  id: 'u1',
  name: 'Priya Mehta',
  email: 'priya@brightair.example',
  emailVerified: true,
  appLanguage: 'en',
  theme: 'system',
  role: 'owner',
  company: CompanyOutModel(
    id: 'c1',
    name: 'BrightAir Services',
    country: 'IN',
    timezone: 'Asia/Kolkata',
    currency: 'INR',
    reportLanguage: 'en',
    plan: 'professional',
    status: 'trial',
    settings: CompanySettingsModel(),
  ),
  permissions: [],
);

DeletionCheckModel check({required bool canDelete, bool needsOwner = false}) => DeletionCheckModel(
      canDelete: canDelete,
      openJobs: 2,
      companies: [
        DeletionCompanyModel(
          companyId: 'c1',
          name: 'BrightAir Services',
          role: 'owner',
          others: needsOwner ? 1 : 0,
          closes: !needsOwner,
          needsNewOwner: needsOwner,
          candidates: needsOwner
              ? const [OwnerCandidateModel(userId: 'u2', name: 'Ravi Kumar', role: 'manager')]
              : const [],
        ),
      ],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockMeRepository repo;
  late SessionService session;

  setUp(() {
    Get.reset();
    Get.testMode = true;
    Get.addTranslations(KnTranslations().keys);
    Get.locale = const Locale('en', 'IN');
    repo = MockMeRepository();
    session = SessionService(tokens: MemoryTokenStorage(), repository: MockAuthRepository())..me.value = owner;
  });

  test('an owner with a team picks a new owner, then can delete', () async {
    var calls = 0;
    when(() => repo.deletionCheck()).thenAnswer((_) async {
      calls++;
      return ApiSuccess(calls == 1 ? check(canDelete: false, needsOwner: true) : check(canDelete: true));
    });
    when(() => repo.changeOwner('u2')).thenAnswer((_) async => const ApiSuccess(owner));
    final c = DeleteAccountController(repository: repo, session: session);
    await c.load();
    expect(c.check.value!.canDelete, isFalse);
    expect(c.canHandOver(c.check.value!.companies.first), isTrue);

    c.understood.value = true;
    expect(c.ready, isFalse);
    c.onDisabledTap();
    expect(c.error.value, 'Choose a new owner for your company first.');

    c.newOwner['c1'] = 'u2';
    await _ignoreApp(() => c.onHandOver(c.check.value!.companies.first));
    verify(() => repo.changeOwner('u2')).called(1);
    expect(c.check.value!.canDelete, isTrue);
    expect(c.ready, isTrue);
  });

  test('deleting sends the reason and forgets the login', () async {
    when(() => repo.deletionCheck()).thenAnswer((_) async => ApiSuccess(check(canDelete: true)));
    when(() => repo.deleteAccount(reason: any(named: 'reason'))).thenAnswer((_) async => const ApiSuccess<void>(null));
    final c = DeleteAccountController(repository: repo, session: session);
    await c.load();
    c.onDisabledTap();
    expect(c.error.value, 'Tick the box to confirm.');

    c.understood.value = true;
    c.reason.text = '  Closing the business ';
    await _ignoreApp(c.onDelete);
    verify(() => repo.deleteAccount(reason: 'Closing the business')).called(1);
    expect(session.me.value, isNull);
  });

  test('a refusal from the server is shown and the check is loaded again', () async {
    when(() => repo.deletionCheck()).thenAnswer((_) async => ApiSuccess(check(canDelete: true)));
    when(() => repo.deleteAccount(reason: any(named: 'reason'))).thenAnswer(
      (_) async => const ApiFailure<void>(
        ApiException(code: 'owner_has_team', message: 'Choose a new owner for your company first.'),
      ),
    );
    final c = DeleteAccountController(repository: repo, session: session);
    await c.load();
    c.understood.value = true;
    await _ignoreApp(c.onDelete);
    expect(c.error.value, 'Choose a new owner for your company first.');
    expect(c.deleting.value, isFalse);
    verify(() => repo.deletionCheck()).called(2);
    expect(session.me.value, isNotNull);
  });
}
