import '../../commons/constants/apis/api_constant.dart';
import '../networks/api_client.dart';

/// Customers: the search on New job (M16).
abstract class ICustomersApiProvider {
  Future<dynamic> getCustomers(Map<String, dynamic> query);
}

class CustomersApiProvider implements ICustomersApiProvider {
  CustomersApiProvider(this._client);

  final ApiClient _client;

  @override
  Future<dynamic> getCustomers(Map<String, dynamic> query) => _client.get(APIConstant.customersAPIEP, query: query);
}
