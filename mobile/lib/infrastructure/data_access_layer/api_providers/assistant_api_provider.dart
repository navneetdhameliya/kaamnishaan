import '../../commons/constants/apis/api_constant.dart';
import '../networks/api_client.dart';

/// M36 Ask KaamNishaan AI. Returns raw JSON.
abstract class IAssistantApiProvider {
  Future<dynamic> getChat();
  Future<dynamic> postAsk(String text);
}

class AssistantApiProvider implements IAssistantApiProvider {
  AssistantApiProvider(this._client);

  final ApiClient _client;

  @override
  Future<dynamic> getChat() => _client.get(APIConstant.assistantAPIEP);

  @override
  Future<dynamic> postAsk(String text) => _client.post(APIConstant.assistantAskAPIEP, body: {'text': text});
}
