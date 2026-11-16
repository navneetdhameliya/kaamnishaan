import 'package:flutter_test/flutter_test.dart';
import 'package:kaamnishaan/infrastructure/commons/constants/app_routes.dart';
import 'package:kaamnishaan/infrastructure/data_access_layer/networks/api_exception.dart';
import 'package:kaamnishaan/infrastructure/data_access_layer/networks/api_result.dart';
import 'package:kaamnishaan/infrastructure/models/api_models.g.dart';
import 'package:kaamnishaan/infrastructure/services/session_service.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/fakes.dart';

void main() {
  late MockAuthRepository repo;
  late MemoryTokenStorage tokens;
  late SessionService service;

  setUp(() {
    repo = MockAuthRepository();
    tokens = MemoryTokenStorage();
    service = SessionService(tokens: tokens, repository: repo);
  });

  test('apply saves the tokens and the person', () async {
    await service.apply(session());
    expect(tokens.access, 'access-1');
    expect(service.me.value?.name, 'Ramesh Patel');
    expect(service.isLoggedIn, isTrue);
  });

  test('next screen follows the backend needs', () async {
    await service.apply(session(needs: ['create_or_join_company', 'profile']));
    expect(service.nextRoute(), RoutesConstants.joinCompanyScreen);
    await service.apply(session(needs: ['profile']));
    expect(service.nextRoute(), RoutesConstants.profileSetupScreen);
    await service.apply(session(needs: ['choose_company']));
    expect(service.nextRoute(), RoutesConstants.chooseCompanyScreen);
    await service.apply(session());
    expect(service.nextRoute(), RoutesConstants.homeScreen);
  });

  test('restore: nothing saved means a fresh start', () async {
    expect(await service.restore(), isNull);
    verifyNever(() => repo.refreshSession());
  });

  test('restore: a saved login is renewed', () async {
    tokens.refresh = 'r';
    when(() => repo.refreshSession()).thenAnswer((_) async => ApiSuccess<SessionOutModel>(session()));
    expect(await service.restore(), RoutesConstants.homeScreen);
  });

  test('restore: offline keeps the user signed in', () async {
    tokens.refresh = 'r';
    when(() => repo.refreshSession()).thenAnswer(
      (_) async => const ApiFailure<SessionOutModel>(ApiException(code: 'no_internet', message: '')),
    );
    expect(await service.restore(), RoutesConstants.homeScreen);
    expect(tokens.refresh, 'r');
  });

  test('restore: a refused login is cleared', () async {
    tokens.refresh = 'r';
    when(() => repo.refreshSession()).thenAnswer(
      (_) async => const ApiFailure<SessionOutModel>(ApiException(code: 'session_expired', message: '')),
    );
    expect(await service.restore(), isNull);
    expect(tokens.refresh, isNull);
  });
}
