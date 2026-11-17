import '../../commons/constants/apis/api_constant.dart';
import '../networks/api_client.dart';

/// Messages (M42).
abstract class INotificationsApiProvider {
  Future<dynamic> getNotifications(Map<String, dynamic> query);
  Future<dynamic> postRead(Map<String, dynamic> body);
}

class NotificationsApiProvider implements INotificationsApiProvider {
  NotificationsApiProvider(this._client);

  final ApiClient _client;

  @override
  Future<dynamic> getNotifications(Map<String, dynamic> query) =>
      _client.get(APIConstant.notificationsAPIEP, query: query);

  @override
  Future<dynamic> postRead(Map<String, dynamic> body) => _client.post(APIConstant.notificationsReadAPIEP, body: body);
}
