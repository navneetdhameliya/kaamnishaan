import '../../models/api_models.g.dart';
import '../api_providers/notifications_api_provider.dart';
import '../networks/api_result.dart';

abstract class INotificationsApiRepository {
  /// Newest first; `meta.counts['unread']` for the red dot.
  Future<ApiResult<NotificationListModel>> list({String? cursor, int limit = 30});

  /// Marks [ids] (or everything when null) as read; returns how many are still unread.
  Future<ApiResult<int>> read({List<String>? ids});
}

class NotificationsApiRepository implements INotificationsApiRepository {
  NotificationsApiRepository({required this.provider});

  final INotificationsApiProvider provider;

  @override
  Future<ApiResult<NotificationListModel>> list({String? cursor, int limit = 30}) => guard(
        () async => NotificationListModel.fromJson(
          Map<String, dynamic>.from(await provider.getNotifications({'limit': limit, 'cursor': ?cursor}) as Map),
        ),
      );

  @override
  Future<ApiResult<int>> read({List<String>? ids}) => guard(() async {
        final json = Map<String, dynamic>.from(await provider.postRead({'ids': ?ids}) as Map);
        return (json['unread'] as num).toInt();
      });
}
