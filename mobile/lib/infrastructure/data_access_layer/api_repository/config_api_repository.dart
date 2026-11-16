import '../../models/api_models.g.dart';
import '../api_providers/config_api_provider.dart';
import '../networks/api_result.dart';

abstract class IConfigApiRepository {
  Future<ApiResult<ConfigOutModel>> getConfig();
}

class ConfigApiRepository implements IConfigApiRepository {
  ConfigApiRepository(this._provider);

  final IConfigApiProvider _provider;

  @override
  Future<ApiResult<ConfigOutModel>> getConfig() =>
      guard(() async => ConfigOutModel.fromJson(Map<String, dynamic>.from(await _provider.getConfig() as Map)));
}
