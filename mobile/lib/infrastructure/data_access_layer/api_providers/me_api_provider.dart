import '../../commons/constants/apis/api_constant.dart';
import '../networks/api_client.dart';

/// The Me tab (M37): counts, app language (M38) and my reports (M30).
abstract class IMeApiProvider {
  Future<dynamic> getStats();
  Future<dynamic> patchPreferences(Map<String, dynamic> body);
  Future<dynamic> getReports(Map<String, dynamic> query);
}

class MeApiProvider implements IMeApiProvider {
  MeApiProvider(this._client);

  final ApiClient _client;

  @override
  Future<dynamic> getStats() => _client.get(APIConstant.meStatsAPIEP);

  @override
  Future<dynamic> patchPreferences(Map<String, dynamic> body) =>
      _client.patch(APIConstant.mePreferencesAPIEP, body: body);

  @override
  Future<dynamic> getReports(Map<String, dynamic> query) => _client.get(APIConstant.reportsAPIEP, query: query);
}
