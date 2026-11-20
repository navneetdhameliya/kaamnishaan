import '../../commons/constants/apis/api_constant.dart';
import '../networks/api_client.dart';

/// Help (M47): the person's help requests to KaamNishaan support.
abstract class ISupportApiProvider {
  Future<dynamic> getTickets();
  Future<dynamic> postTicket(Map<String, dynamic> body);
  Future<dynamic> getTicket(String id);
  Future<dynamic> postReply(String id, Map<String, dynamic> body);
  Future<dynamic> postSolve(String id);
}

class SupportApiProvider implements ISupportApiProvider {
  SupportApiProvider(this._client);

  final ApiClient _client;

  @override
  Future<dynamic> getTickets() => _client.get(APIConstant.supportTicketsAPIEP);

  @override
  Future<dynamic> postTicket(Map<String, dynamic> body) => _client.post(APIConstant.supportTicketsAPIEP, body: body);

  @override
  Future<dynamic> getTicket(String id) => _client.get('${APIConstant.supportTicketsAPIEP}/$id');

  @override
  Future<dynamic> postReply(String id, Map<String, dynamic> body) =>
      _client.post('${APIConstant.supportTicketsAPIEP}/$id/messages', body: body);

  @override
  Future<dynamic> postSolve(String id) => _client.post('${APIConstant.supportTicketsAPIEP}/$id/solve');
}
