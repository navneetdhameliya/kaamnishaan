import '../../models/api_models.g.dart';
import '../api_providers/home_api_provider.dart';
import '../networks/api_result.dart';

abstract class IHomeApiRepository {
  Future<ApiResult<TodayModel>> today();
  Future<ApiResult<DashboardModel>> dashboard();

  /// Reports waiting for the manager, oldest first (M13 "Waiting for your review").
  Future<ApiResult<ReportListModel>> reviewQueue({int limit = 3});
}

class HomeApiRepository implements IHomeApiRepository {
  HomeApiRepository({required this.provider});

  final IHomeApiProvider provider;

  Map<String, dynamic> _map(dynamic json) => Map<String, dynamic>.from(json as Map);

  @override
  Future<ApiResult<TodayModel>> today() => guard(() async => TodayModel.fromJson(_map(await provider.getToday())));

  @override
  Future<ApiResult<DashboardModel>> dashboard() =>
      guard(() async => DashboardModel.fromJson(_map(await provider.getDashboard())));

  @override
  Future<ApiResult<ReportListModel>> reviewQueue({int limit = 3}) => guard(() async =>
      ReportListModel.fromJson(_map(await provider.getReports({'status': 'pending_review', 'limit': limit}))));
}
