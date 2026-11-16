import 'package:dio/dio.dart';
import 'package:get/get.dart';

import '../../lang/lang_keys.g.dart';

import '../../shared/app_logger.dart';
import 'api_exception.dart';

/// What a repository returns: the data, or the reason it failed. No exceptions leak to screens.
sealed class ApiResult<T> {
  const ApiResult();

  bool get isSuccess => this is ApiSuccess<T>;
  T? get dataOrNull => switch (this) { ApiSuccess(:final data) => data, ApiFailure() => null };
  ApiException? get errorOrNull => switch (this) { ApiSuccess() => null, ApiFailure(:final error) => error };
}

final class ApiSuccess<T> extends ApiResult<T> {
  const ApiSuccess(this.data);
  final T data;
}

final class ApiFailure<T> extends ApiResult<T> {
  const ApiFailure(this.error);
  final ApiException error;
}

/// Runs a call and turns any failure into [ApiFailure].
Future<ApiResult<T>> guard<T>(Future<T> Function() call) async {
  try {
    return ApiSuccess(await call());
  } on ApiException catch (e) {
    return ApiFailure(e);
  } on DioException catch (e) {
    return ApiFailure(ApiException.fromDio(e));
  } catch (e, st) {
    AppLogger.error('Unexpected error', error: e, stackTrace: st);
    return ApiFailure(ApiException(code: 'unknown', message: LangKeys.errorUnknown.tr));
  }
}
