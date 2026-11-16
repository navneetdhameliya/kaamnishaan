import '../../commons/constants/apis/api_constant.dart';
import '../networks/api_client.dart';

/// The company: create it (M07) and change its details. Returns raw JSON; the repository makes models.
abstract class ICompanyApiProvider {
  Future<dynamic> postCompany(Map<String, dynamic> body);
  Future<dynamic> patchCompany(Map<String, dynamic> body);
}

class CompanyApiProvider implements ICompanyApiProvider {
  CompanyApiProvider(this._client);

  final ApiClient _client;

  @override
  Future<dynamic> postCompany(Map<String, dynamic> body) => _client.post(APIConstant.companiesAPIEP, body: body);

  @override
  Future<dynamic> patchCompany(Map<String, dynamic> body) => _client.patch(APIConstant.companyAPIEP, body: body);
}
