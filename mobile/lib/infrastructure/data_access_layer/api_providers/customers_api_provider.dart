import '../../commons/constants/apis/api_constant.dart';
import '../networks/api_client.dart';

/// Customers: the search on New job (M16) and Customer details (M18).
abstract class ICustomersApiProvider {
  Future<dynamic> getCustomers(Map<String, dynamic> query);
  Future<dynamic> getCustomer(String id);
  Future<dynamic> getCustomerJobs(String id, Map<String, dynamic> query);
  Future<dynamic> postCustomer(Map<String, dynamic> body);
  Future<dynamic> patchCustomer(String id, Map<String, dynamic> body);
  Future<dynamic> postContact(String id, Map<String, dynamic> body);
  Future<dynamic> patchContact(String id, String contactId, Map<String, dynamic> body);
  Future<dynamic> postSite(String id, Map<String, dynamic> body);
  Future<dynamic> patchSite(String id, String siteId, Map<String, dynamic> body);
}

class CustomersApiProvider implements ICustomersApiProvider {
  CustomersApiProvider(this._client);

  final ApiClient _client;

  @override
  Future<dynamic> getCustomers(Map<String, dynamic> query) => _client.get(APIConstant.customersAPIEP, query: query);

  @override
  Future<dynamic> getCustomer(String id) => _client.get(APIConstant.customerAPIEP(id));

  @override
  Future<dynamic> getCustomerJobs(String id, Map<String, dynamic> query) =>
      _client.get(APIConstant.customerJobsAPIEP(id), query: query);

  @override
  Future<dynamic> postCustomer(Map<String, dynamic> body) => _client.post(APIConstant.customersAPIEP, body: body);

  @override
  Future<dynamic> patchCustomer(String id, Map<String, dynamic> body) =>
      _client.patch(APIConstant.customerAPIEP(id), body: body);

  @override
  Future<dynamic> postContact(String id, Map<String, dynamic> body) =>
      _client.post(APIConstant.customerContactsAPIEP(id), body: body);

  @override
  Future<dynamic> patchContact(String id, String contactId, Map<String, dynamic> body) =>
      _client.patch(APIConstant.customerContactAPIEP(id, contactId), body: body);

  @override
  Future<dynamic> postSite(String id, Map<String, dynamic> body) => _client.post(APIConstant.customerSitesAPIEP(id), body: body);

  @override
  Future<dynamic> patchSite(String id, String siteId, Map<String, dynamic> body) =>
      _client.patch(APIConstant.customerSiteAPIEP(id, siteId), body: body);
}
