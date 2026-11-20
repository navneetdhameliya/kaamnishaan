import '../../models/api_models.g.dart';
import '../api_providers/support_api_provider.dart';
import '../networks/api_result.dart';

abstract class ISupportApiRepository {
  /// This person's requests in this company, latest activity first.
  Future<ApiResult<List<TicketOutModel>>> list();

  Future<ApiResult<TicketOutModel>> create(TicketCreateModel body);

  /// The request with every message, oldest first.
  Future<ApiResult<TicketOutModel>> get(String id);

  /// Writing again opens a solved request again.
  Future<ApiResult<TicketOutModel>> reply(String id, String text);

  Future<ApiResult<TicketOutModel>> solve(String id);
}

class SupportApiRepository implements ISupportApiRepository {
  SupportApiRepository({required this.provider});

  final ISupportApiProvider provider;

  TicketOutModel _one(dynamic json) => TicketOutModel.fromJson(Map<String, dynamic>.from(json as Map));

  @override
  Future<ApiResult<List<TicketOutModel>>> list() => guard(
        () async => TicketListModel.fromJson(Map<String, dynamic>.from(await provider.getTickets() as Map)).data,
      );

  @override
  Future<ApiResult<TicketOutModel>> create(TicketCreateModel body) =>
      guard(() async => _one(await provider.postTicket(body.toJson()..removeWhere((_, v) => v == null))));

  @override
  Future<ApiResult<TicketOutModel>> get(String id) => guard(() async => _one(await provider.getTicket(id)));

  @override
  Future<ApiResult<TicketOutModel>> reply(String id, String text) =>
      guard(() async => _one(await provider.postReply(id, {'body': text})));

  @override
  Future<ApiResult<TicketOutModel>> solve(String id) => guard(() async => _one(await provider.postSolve(id)));
}
