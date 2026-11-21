import '../../commons/constants/apis/api_constant.dart';
import '../networks/api_client.dart';

/// A job's voice notes and typed notes (M27–M29).
abstract class IVoiceApiProvider {
  Future<dynamic> getNotes(String jobId);
  Future<dynamic> getNote(String id);
  Future<dynamic> postVoiceNote(String jobId, Map<String, dynamic> body);
  Future<dynamic> postTypedNote(String jobId, Map<String, dynamic> body);
  Future<dynamic> patchNote(String id, Map<String, dynamic> body);
  Future<dynamic> postRetranscribe(String id, Map<String, dynamic> body);
  Future<dynamic> deleteNote(String id);
  Future<dynamic> postDictation(Map<String, dynamic> body);
}

class VoiceApiProvider implements IVoiceApiProvider {
  VoiceApiProvider(this._client);

  final ApiClient _client;

  @override
  Future<dynamic> getNotes(String jobId) => _client.get(APIConstant.jobVoiceNotesAPIEP(jobId));

  @override
  Future<dynamic> getNote(String id) => _client.get(APIConstant.voiceNoteAPIEP(id));

  @override
  Future<dynamic> postVoiceNote(String jobId, Map<String, dynamic> body) =>
      _client.post(APIConstant.jobVoiceNotesAPIEP(jobId), body: body);

  @override
  Future<dynamic> postTypedNote(String jobId, Map<String, dynamic> body) =>
      _client.post(APIConstant.jobTypedNotesAPIEP(jobId), body: body);

  @override
  Future<dynamic> patchNote(String id, Map<String, dynamic> body) =>
      _client.patch(APIConstant.voiceNoteAPIEP(id), body: body);

  @override
  Future<dynamic> postRetranscribe(String id, Map<String, dynamic> body) =>
      _client.post(APIConstant.retranscribeAPIEP(id), body: body);

  @override
  Future<dynamic> deleteNote(String id) => _client.delete(APIConstant.voiceNoteAPIEP(id));

  @override
  Future<dynamic> postDictation(Map<String, dynamic> body) => _client.post(APIConstant.dictationAPIEP, body: body);
}
