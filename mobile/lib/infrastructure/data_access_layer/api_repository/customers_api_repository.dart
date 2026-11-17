import '../../models/api_models.g.dart';
import '../api_providers/customers_api_provider.dart';
import '../networks/api_result.dart';

abstract class ICustomersApiRepository {
  /// Customers whose name or phone matches [q] (all when empty), each with its first address.
  Future<ApiResult<CustomerListModel>> search(String q);
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
}
