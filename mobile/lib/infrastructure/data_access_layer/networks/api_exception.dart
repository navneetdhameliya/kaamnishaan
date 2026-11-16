import 'package:dio/dio.dart';
import 'package:get/get.dart';

import '../../lang/lang_keys.g.dart';

/// Every failed call ends up as one of these. `code` matches the backend's error codes
/// (otp_invalid, otp_expired, invite_expired …) plus no_internet / timeout / unknown.
class ApiException implements Exception {
  const ApiException({
    required this.code,
    required this.message,
    this.fields = const {},
    this.details = const {},
    this.statusCode,
  });

  final String code;
  final String message;
  final Map<String, String> fields;
  final Map<String, dynamic> details;
  final int? statusCode;

  bool get isNetwork => code == 'no_internet' || code == 'timeout';

  /// Reads the backend envelope `{error: {code, message, fields, details}}`.
  factory ApiException.fromDio(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException(code: 'timeout', message: LangKeys.errorTimeout.tr);
      case DioExceptionType.connectionError:
        return ApiException(code: 'no_internet', message: LangKeys.errorNoInternet.tr);
      default:
        break;
    }
    final data = e.response?.data;
    final error = data is Map ? data['error'] : null;
    if (error is Map) {
      final fields = error['fields'];
      final details = error['details'];
      return ApiException(
        code: (error['code'] ?? 'unknown').toString(),
        message: (error['message'] ?? LangKeys.errorUnknown.tr).toString(),
        fields: fields is Map ? fields.map((k, v) => MapEntry(k.toString(), v.toString())) : const {},
        details: details is Map ? Map<String, dynamic>.from(details) : const {},
        statusCode: e.response?.statusCode,
      );
    }
    return ApiException(code: 'unknown', message: LangKeys.errorUnknown.tr, statusCode: e.response?.statusCode);
  }

  @override
  String toString() => 'ApiException($code, $statusCode): $message';
}
