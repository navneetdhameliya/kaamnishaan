import '../../commons/constants/apis/api_constant.dart';
import '../networks/api_client.dart';

/// App settings from the server: languages, countries, trades, minimum app version.
abstract class IConfigApiProvider {
  Future<dynamic> getConfig();

  /// Texts staff changed in the admin panel (A25), for the app, in every language.
  Future<dynamic> getTexts();
}

class ConfigApiProvider implements IConfigApiProvider {
  ConfigApiProvider(this._client);

  final ApiClient _client;

  @override
  Future<dynamic> getConfig() => _client.get(APIConstant.configAPIEP, options: ApiClient.public);

  @override
  Future<dynamic> getTexts() =>
      _client.get(APIConstant.publicTextsAPIEP, query: {'area': 'app'}, options: ApiClient.public);
}
