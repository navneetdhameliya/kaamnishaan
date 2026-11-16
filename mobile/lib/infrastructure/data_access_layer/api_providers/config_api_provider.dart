import '../../commons/constants/apis/api_constant.dart';
import '../networks/api_client.dart';

/// App settings from the server: languages, countries, trades, minimum app version.
abstract class IConfigApiProvider {
  Future<dynamic> getConfig();
}

class ConfigApiProvider implements IConfigApiProvider {
  ConfigApiProvider(this._client);

  final ApiClient _client;

  @override
  Future<dynamic> getConfig() => _client.get(APIConstant.configAPIEP, options: ApiClient.public);
}
