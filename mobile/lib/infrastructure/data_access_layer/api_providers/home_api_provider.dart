import '../../commons/constants/apis/api_constant.dart';
import '../networks/api_client.dart';

/// Home screens: the technician's Today (M12) and the manager's dashboard (M13).
abstract class IHomeApiProvider {
  Future<dynamic> getToday();
  Future<dynamic> getDashboard();
  Future<dynamic> getReports(Map<String, dynamic> query);
}

class HomeApiProvider implements IHomeApiProvider {
  HomeApiProvider(this._client);

  final ApiClient _client;

  @override
  Future<dynamic> getToday() => _client.get(APIConstant.todayAPIEP);

  @override
  Future<dynamic> getDashboard() => _client.get(APIConstant.dashboardAPIEP);

  @override
  Future<dynamic> getReports(Map<String, dynamic> query) => _client.get(APIConstant.reportsAPIEP, query: query);
}
