import '../../models/api_models.g.dart';
import '../api_providers/me_api_provider.dart';
import '../networks/api_result.dart';

abstract class IMeApiRepository {
  /// "14 jobs done · 96 photos · 12 reports" (owners and managers also get team and customers).
  Future<ApiResult<MeStatsModel>> stats();

  /// Keeps the app language on the account, so other phones and messages use it.
  Future<ApiResult<MeOutModel>> setLanguage(String code);

  /// My reports (M30): this week's, optionally only some states.
  Future<ApiResult<ReportListModel>> myReports({List<String>? statuses, String period = 'week', String? cursor});

  /// D-130: what deleting the account would do (companies left or closed, an owner to pick first).
  Future<ApiResult<DeletionCheckModel>> deletionCheck();

  /// D-130: deletes the account now; the server logs this person out everywhere.
  Future<ApiResult<void>> deleteAccount({String? reason});

  /// The owner hands the current company to someone in the team and becomes a manager.
  Future<ApiResult<MeOutModel>> changeOwner(String userId);
}

class MeApiRepository implements IMeApiRepository {
  MeApiRepository({required this.provider});

  final IMeApiProvider provider;

  Map<String, dynamic> _map(dynamic json) => Map<String, dynamic>.from(json as Map);

  @override
  Future<ApiResult<MeStatsModel>> stats() => guard(() async => MeStatsModel.fromJson(_map(await provider.getStats())));

  @override
  Future<ApiResult<MeOutModel>> setLanguage(String code) =>
      guard(() async => MeOutModel.fromJson(_map(await provider.patchPreferences({'app_language': code}))));

  @override
  Future<ApiResult<ReportListModel>> myReports({List<String>? statuses, String period = 'week', String? cursor}) =>
      guard(
        () async => ReportListModel.fromJson(
          _map(
            await provider.getReports({
              'mine': true,
              'period': period,
              'status': ?statuses,
              'cursor': ?cursor,
              'limit': 50,
            }),
          ),
        ),
      );

  @override
  Future<ApiResult<DeletionCheckModel>> deletionCheck() =>
      guard(() async => DeletionCheckModel.fromJson(_map(await provider.getDeletion())));

  @override
  Future<ApiResult<void>> deleteAccount({String? reason}) => guard(() async {
        await provider.postDelete({'confirm': true, 'reason': ?reason});
      });

  @override
  Future<ApiResult<MeOutModel>> changeOwner(String userId) =>
      guard(() async => MeOutModel.fromJson(_map(await provider.postOwner({'user_id': userId}))));
}
