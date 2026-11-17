import '../../models/api_models.g.dart';
import '../api_providers/assistant_api_provider.dart';
import '../networks/api_result.dart';

abstract class IAssistantApiRepository {
  /// M36: my recent questions and answers, and this month's question count.
  Future<ApiResult<AssistantOutModel>> chat();

  /// M36: ask about the company's jobs. Fails with `ai_limit_reached` when the month's questions are used up,
  /// `assistant_unavailable` while the AI service isn't set up.
  Future<ApiResult<AskOutModel>> ask(String text);
}

class AssistantApiRepository implements IAssistantApiRepository {
  AssistantApiRepository({required this.provider});

  final IAssistantApiProvider provider;

  Map<String, dynamic> _map(dynamic json) => Map<String, dynamic>.from(json as Map);

  @override
  Future<ApiResult<AssistantOutModel>> chat() =>
      guard(() async => AssistantOutModel.fromJson(_map(await provider.getChat())));

  @override
  Future<ApiResult<AskOutModel>> ask(String text) =>
      guard(() async => AskOutModel.fromJson(_map(await provider.postAsk(text))));
}
