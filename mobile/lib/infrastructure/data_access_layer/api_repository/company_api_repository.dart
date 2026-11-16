import '../../models/api_models.g.dart';
import '../api_providers/company_api_provider.dart';
import '../networks/api_result.dart';

abstract class ICompanyApiRepository {
  Future<ApiResult<CompanyOutModel>> createCompany({
    required String name,
    required String trade,
    required String country,
    required String timezone,
  });
  Future<ApiResult<CompanyOutModel>> setLogo(String uploadId);
}

class CompanyApiRepository implements ICompanyApiRepository {
  CompanyApiRepository({required this.provider});

  final ICompanyApiProvider provider;

  Map<String, dynamic> _map(dynamic json) => Map<String, dynamic>.from(json as Map);

  @override
  Future<ApiResult<CompanyOutModel>> createCompany({
    required String name,
    required String trade,
    required String country,
    required String timezone,
  }) =>
      guard(() async => CompanyOutModel.fromJson(_map(await provider.postCompany({
            'name': name.trim(),
            'trade': trade,
            'country': country,
            'timezone': timezone,
          }))));

  @override
  Future<ApiResult<CompanyOutModel>> setLogo(String uploadId) =>
      guard(() async => CompanyOutModel.fromJson(_map(await provider.patchCompany({'logo_upload_id': uploadId}))));
}
