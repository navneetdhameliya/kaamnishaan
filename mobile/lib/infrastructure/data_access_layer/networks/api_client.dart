import 'dart:async';

import 'package:dio/dio.dart';

import '../../commons/constants/apis/api_constant.dart';
import '../../config/env.dart';
import '../../services/token_storage_service.dart';
import '../../shared/app_logger.dart';

/// The one HTTP client. Adds the login token, app language and device id to every call,
/// refreshes the token once on 401 and repeats the call, and logs the user out if that fails.
class ApiClient {
  ApiClient({
    required this.tokens,
    required this.language,
    required this.deviceId,
    this.onSessionExpired,
    String? baseUrl,
    Dio? dio,
    Dio? refreshDio,
    Dio? uploadDio,
  })  : dio = dio ?? Dio(),
        _refreshDio = refreshDio ?? Dio(),
        _uploadDio = uploadDio ?? Dio(BaseOptions(sendTimeout: const Duration(minutes: 2))) {
    final options = BaseOptions(
      baseUrl: '${baseUrl ?? Env.apiUrl}${APIConstant.apiPrefix}',
      // the free test server can take about a minute to wake up
      connectTimeout: const Duration(seconds: 75),
      receiveTimeout: const Duration(seconds: 75),
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
    );
    this.dio.options = options;
    _refreshDio.options = options;
    this.dio.interceptors.add(QueuedInterceptorsWrapper(onRequest: _onRequest, onError: _onError));
  }

  final Dio dio;
  final Dio _refreshDio;
  final Dio _uploadDio;
  final ITokenStorage tokens;
  final String Function() language;
  final Future<String> Function() deviceId;
  final void Function()? onSessionExpired;
  Future<bool>? _refreshing;

  static const _noAuth = 'kn_no_auth';
  static const _retried = 'kn_retried';

  /// Options for calls made before login (OTP, config).
  static Options get public => Options(extra: {_noAuth: true});

  Future<dynamic> get(String path, {Map<String, dynamic>? query, Options? options}) async =>
      (await dio.get<dynamic>(path, queryParameters: query, options: options)).data;

  Future<dynamic> post(String path, {Object? body, Options? options}) async =>
      (await dio.post<dynamic>(path, data: body, options: options)).data;

  Future<dynamic> patch(String path, {Object? body, Options? options}) async =>
      (await dio.patch<dynamic>(path, data: body, options: options)).data;

  Future<dynamic> delete(String path, {Options? options}) async =>
      (await dio.delete<dynamic>(path, options: options)).data;

  /// Step 2 of an upload: PUT the bytes to the signed storage URL (no login token; the URL is the permission).
  Future<void> putBytes(String url, List<int> bytes, Map<String, String> headers) async {
    await _uploadDio.put<dynamic>(
      url,
      data: Stream.fromIterable([bytes]),
      options: Options(headers: {...headers, Headers.contentLengthHeader: bytes.length}),
    );
  }

  Future<void> _onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    options.headers['Accept-Language'] = language();
    options.headers['X-Device-Id'] = await deviceId();
    if (options.extra[_noAuth] != true) {
      final token = await tokens.readAccess();
      if (token != null) options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  Future<void> _onError(DioException err, ErrorInterceptorHandler handler) async {
    final options = err.requestOptions;
    final unauthorised = err.response?.statusCode == 401;
    if (!unauthorised || options.extra[_noAuth] == true || options.extra[_retried] == true) {
      return handler.next(err);
    }
    if (await refreshTokens()) {
      final token = await tokens.readAccess();
      options.headers['Authorization'] = 'Bearer $token';
      options.extra[_retried] = true;
      try {
        return handler.resolve(await dio.fetch<dynamic>(options));
      } on DioException catch (e) {
        return handler.next(e);
      }
    }
    onSessionExpired?.call();
    handler.next(err);
  }

  /// Swaps the refresh token for a new pair. Several 401s at once share one refresh.
  Future<bool> refreshTokens() => _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);

  Future<bool> _doRefresh() async {
    final refresh = await tokens.readRefresh();
    if (refresh == null) return false;
    try {
      final res = await _refreshDio.post<dynamic>(
        APIConstant.refreshTokenAPIEP,
        data: {'refresh_token': refresh},
        options: Options(headers: {'Accept-Language': language(), 'X-Device-Id': await deviceId()}),
      );
      final data = res.data;
      if (data is Map && data['access_token'] is String && data['refresh_token'] is String) {
        await tokens.save(data['access_token'] as String, data['refresh_token'] as String);
        lastRefreshed = Map<String, dynamic>.from(data);
        return true;
      }
    } on DioException catch (e) {
      AppLogger.error('Token refresh failed', error: e);
      if (e.response?.statusCode == 401) await tokens.clear();
    }
    return false;
  }

  /// The session returned by the last successful refresh (the app reads the user and companies from it).
  Map<String, dynamic>? lastRefreshed;
}
