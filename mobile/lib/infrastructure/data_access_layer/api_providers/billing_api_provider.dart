import '../../commons/constants/apis/api_constant.dart';
import '../networks/api_client.dart';

/// M41 Plan and billing, Follow-up credits. Returns raw JSON.
abstract class IBillingApiProvider {
  Future<dynamic> getBilling();
  Future<dynamic> getCredits();
}

class BillingApiProvider implements IBillingApiProvider {
  BillingApiProvider(this._client);

  final ApiClient _client;

  @override
  Future<dynamic> getBilling() => _client.get(APIConstant.billingAPIEP);

  @override
  Future<dynamic> getCredits() => _client.get(APIConstant.creditsAPIEP);
}
