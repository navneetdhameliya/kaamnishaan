import '../../commons/constants/apis/api_constant.dart';
import '../networks/api_client.dart';

/// File uploads: ask for a signed URL, then PUT the bytes there.
abstract class IFilesApiProvider {
  Future<dynamic> postUpload(Map<String, dynamic> body);
  Future<void> putFile(String url, List<int> bytes, Map<String, String> headers);
}

class FilesApiProvider implements IFilesApiProvider {
  FilesApiProvider(this._client);

  final ApiClient _client;

  @override
  Future<dynamic> postUpload(Map<String, dynamic> body) => _client.post(APIConstant.uploadsAPIEP, body: body);

  @override
  Future<void> putFile(String url, List<int> bytes, Map<String, String> headers) =>
      _client.putBytes(url, bytes, headers);
}
