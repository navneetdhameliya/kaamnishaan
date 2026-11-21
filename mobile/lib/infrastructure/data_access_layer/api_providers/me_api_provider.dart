import '../../commons/constants/apis/api_constant.dart';
import '../networks/api_client.dart';

/// The Me tab (M37): counts, app language (M38), my reports (M30) and deleting the account (D-130).
abstract class IMeApiProvider {
  Future<dynamic> getStats();
  Future<dynamic> patchPreferences(Map<String, dynamic> body);
  Future<dynamic> getReports(Map<String, dynamic> query);
  Future<dynamic> getDeletion();
  Future<dynamic> postDelete(Map<String, dynamic> body);
  Future<dynamic> postOwner(Map<String, dynamic> body);
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

  @override
  Future<dynamic> getDeletion() => _client.get(APIConstant.meDeletionAPIEP);

  @override
  Future<dynamic> postDelete(Map<String, dynamic> body) => _client.post(APIConstant.meDeleteAPIEP, body: body);

  @override
  Future<dynamic> postOwner(Map<String, dynamic> body) => _client.post(APIConstant.companyOwnerAPIEP, body: body);
}
