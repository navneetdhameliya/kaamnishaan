import '../../models/api_models.g.dart';
import '../api_providers/customers_api_provider.dart';
import '../networks/api_result.dart';

abstract class ICustomersApiRepository {
  /// Customers whose name or phone matches [q] (all when empty), each with its first address.
  Future<ApiResult<CustomerListModel>> search(String q);

  /// One customer with contacts and addresses (M18).
  Future<ApiResult<CustomerOutModel>> customer(String id);

  /// Their jobs (M18 "Past jobs").
  Future<ApiResult<JobListModel>> jobs(String id);

  /// The Customers list: a page of 30, searched by name, phone or city, from [cursor].
  Future<ApiResult<CustomerListModel>> page({String q = '', String? cursor});

  /// A new customer, with their first contact and address when given. [clientUuid] makes a retry safe.
  Future<ApiResult<CustomerOutModel>> create(Map<String, dynamic> body);

  /// The name and notes.
  Future<ApiResult<CustomerOutModel>> update(String id, Map<String, dynamic> body);

  /// Adds a contact, or changes one when [contactId] is given.
  Future<ApiResult<ContactOutModel>> saveContact(String id, Map<String, dynamic> body, {String? contactId});

  /// Adds an address, or changes one when [siteId] is given.
  Future<ApiResult<SiteOutModel>> saveSite(String id, Map<String, dynamic> body, {String? siteId});
}

class CustomersApiRepository implements ICustomersApiRepository {
  CustomersApiRepository({required this.provider});

  final ICustomersApiProvider provider;

  @override
  Future<ApiResult<CustomerListModel>> search(String q) => guard(
        () async => CustomerListModel.fromJson(
          Map<String, dynamic>.from(await provider.getCustomers({if (q.trim().isNotEmpty) 'q': q.trim(), 'limit': 20}) as Map),
        ),
      );

  @override
  Future<ApiResult<CustomerOutModel>> customer(String id) => guard(
        () async => CustomerOutModel.fromJson(Map<String, dynamic>.from(await provider.getCustomer(id) as Map)),
      );

  @override
  Future<ApiResult<JobListModel>> jobs(String id) => guard(
        () async => JobListModel.fromJson(
          Map<String, dynamic>.from(await provider.getCustomerJobs(id, {'limit': 50}) as Map),
        ),
      );

  Map<String, dynamic> _map(dynamic json) => Map<String, dynamic>.from(json as Map);

  @override
  Future<ApiResult<CustomerListModel>> page({String q = '', String? cursor}) => guard(
        () async => CustomerListModel.fromJson(_map(await provider.getCustomers({
          if (q.trim().isNotEmpty) 'q': q.trim(),
          'cursor': ?cursor,
          'limit': 30,
        }))),
      );

  @override
  Future<ApiResult<CustomerOutModel>> create(Map<String, dynamic> body) =>
      guard(() async => CustomerOutModel.fromJson(_map(await provider.postCustomer(body))));

  @override
  Future<ApiResult<CustomerOutModel>> update(String id, Map<String, dynamic> body) =>
      guard(() async => CustomerOutModel.fromJson(_map(await provider.patchCustomer(id, body))));

  @override
  Future<ApiResult<ContactOutModel>> saveContact(String id, Map<String, dynamic> body, {String? contactId}) => guard(
        () async => ContactOutModel.fromJson(
          _map(contactId == null ? await provider.postContact(id, body) : await provider.patchContact(id, contactId, body)),
        ),
      );

  @override
  Future<ApiResult<SiteOutModel>> saveSite(String id, Map<String, dynamic> body, {String? siteId}) => guard(
        () async => SiteOutModel.fromJson(
          _map(siteId == null ? await provider.postSite(id, body) : await provider.patchSite(id, siteId, body)),
        ),
      );
}
