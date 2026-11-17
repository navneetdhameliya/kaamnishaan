import '../../models/api_models.g.dart';
import '../api_providers/billing_api_provider.dart';
import '../networks/api_result.dart';

abstract class IBillingApiRepository {
  /// M41 Plan and billing (owner only): the plan, this month's use, the next plan.
  Future<ApiResult<BillingOutModel>> billing();

  /// M41 Follow-up credits (owners and managers): what's left, what used it, the top-up packs.
  Future<ApiResult<CreditsOutModel>> credits();
}

class BillingApiRepository implements IBillingApiRepository {
  BillingApiRepository({required this.provider});

  final IBillingApiProvider provider;

  Map<String, dynamic> _map(dynamic json) => Map<String, dynamic>.from(json as Map);

  @override
  Future<ApiResult<BillingOutModel>> billing() =>
      guard(() async => BillingOutModel.fromJson(_map(await provider.getBilling())));

  @override
  Future<ApiResult<CreditsOutModel>> credits() =>
      guard(() async => CreditsOutModel.fromJson(_map(await provider.getCredits())));
}
