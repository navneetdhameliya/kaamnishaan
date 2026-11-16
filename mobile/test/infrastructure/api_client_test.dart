import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaamnishaan/infrastructure/data_access_layer/networks/api_client.dart';
import 'package:kaamnishaan/infrastructure/data_access_layer/networks/api_exception.dart';
import 'package:kaamnishaan/infrastructure/data_access_layer/networks/api_result.dart';

import '../helpers/fakes.dart';

void main() {
  late MemoryTokenStorage tokens;
  late Dio dio;
  late Dio refreshDio;
  var expired = 0;

  ApiClient client() => ApiClient(
        tokens: tokens,
        language: () => 'hi',
        deviceId: () async => 'device-1',
        onSessionExpired: () => expired++,
        baseUrl: 'https://api.test',
        dio: dio,
        refreshDio: refreshDio,
      );

  setUp(() {
    tokens = MemoryTokenStorage(access: 'old-access', refresh: 'refresh-1');
    dio = Dio();
    refreshDio = Dio();
    expired = 0;
  });

  test('adds token, language and device id', () async {
    final adapter = FakeAdapter((o) => jsonBody({'ok': true}, 200));
    dio.httpClientAdapter = adapter;
    await client().get('/me');
    final sent = adapter.requests.single;
    expect(sent.uri.toString(), 'https://api.test/api/v1/me');
    expect(sent.headers['Authorization'], 'Bearer old-access');
    expect(sent.headers['Accept-Language'], 'hi');
    expect(sent.headers['X-Device-Id'], 'device-1');
  });

  test('public calls carry no token', () async {
    final adapter = FakeAdapter((o) => jsonBody({}, 202));
    dio.httpClientAdapter = adapter;
    await client().post('/auth/otp/send', body: {'phone': '+919825011111'}, options: ApiClient.public);
    expect(adapter.requests.single.headers.containsKey('Authorization'), isFalse);
  });

  test('on 401 refreshes once, saves the new tokens and repeats the call', () async {
    final adapter = FakeAdapter((o) {
      final auth = o.headers['Authorization'];
      return auth == 'Bearer new-access' ? jsonBody({'name': 'Ramesh'}, 200) : jsonBody({'error': {}}, 401);
    });
    dio.httpClientAdapter = adapter;
    refreshDio.httpClientAdapter = FakeAdapter(
      (o) => jsonBody({'access_token': 'new-access', 'refresh_token': 'refresh-2'}, 200),
    );
    final data = await client().get('/me');
    expect(data, {'name': 'Ramesh'});
    expect(tokens.access, 'new-access');
    expect(tokens.refresh, 'refresh-2');
    expect(adapter.requests, hasLength(2));
    expect(expired, 0);
  });

  test('when refresh is refused the session ends', () async {
    dio.httpClientAdapter = FakeAdapter((o) => jsonBody({'error': {}}, 401));
    refreshDio.httpClientAdapter = FakeAdapter((o) => jsonBody({'error': {'code': 'session_expired'}}, 401));
    final result = await guard(() => client().get('/me'));
    expect(result.isSuccess, isFalse);
    expect(tokens.refresh, isNull);
    expect(expired, 1);
  });

  test('reads the error envelope', () async {
    dio.httpClientAdapter = FakeAdapter(
      (o) => jsonBody({
        'error': {
          'code': 'otp_invalid',
          'message': 'Wrong code',
          'fields': {'code': 'wrong'},
          'details': {'attempts_left': 2},
        },
      }, 400),
    );
    final result = await guard(() => client().post('/auth/otp/verify', body: {}, options: ApiClient.public));
    final error = result.errorOrNull!;
    expect(error.code, 'otp_invalid');
    expect(error.message, 'Wrong code');
    expect(error.fields, {'code': 'wrong'});
    expect(error.details['attempts_left'], 2);
    expect(error.statusCode, 400);
  });

  test('no connection becomes no_internet', () {
    final e = ApiException.fromDio(
      DioException(requestOptions: RequestOptions(path: '/me'), type: DioExceptionType.connectionError),
    );
    expect(e.code, 'no_internet');
    expect(e.isNetwork, isTrue);
  });
}
