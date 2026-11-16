import '../../models/api_models.g.dart';
import '../api_providers/files_api_provider.dart';
import '../networks/api_result.dart';

/// What the file is for. The backend checks the type and size for each kind.
enum UploadKind { photo, audio, logo, avatar, signature }

abstract class IFilesApiRepository {
  /// Uploads [bytes] and returns the upload id to confirm with the call that uses the file.
  Future<ApiResult<String>> upload({required UploadKind kind, required List<int> bytes, required String contentType});
}

class FilesApiRepository implements IFilesApiRepository {
  FilesApiRepository({required this.provider});

  final IFilesApiProvider provider;

  @override
  Future<ApiResult<String>> upload({required UploadKind kind, required List<int> bytes, required String contentType}) =>
      guard(() async {
        final signed = UploadOutModel.fromJson(Map<String, dynamic>.from(await provider.postUpload({
          'kind': kind.name,
          'content_type': contentType,
          'size': bytes.length,
        }) as Map));
        await provider.putFile(signed.url, bytes, signed.headers.map((k, v) => MapEntry(k, '$v')));
        return signed.uploadId;
      });
}
