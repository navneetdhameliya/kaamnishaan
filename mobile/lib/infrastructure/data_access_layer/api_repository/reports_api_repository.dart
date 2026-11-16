import '../../models/api_models.g.dart';
import '../api_providers/reports_api_provider.dart';
import '../networks/api_result.dart';

abstract class IReportsApiRepository {
  /// Starts writing the job's report (or returns the one being written).
  Future<ApiResult<ReportStartedModel>> start(String jobId);

  /// How far the writing is (M31 "Making your report").
  Future<ApiResult<TaskOutModel>> task(String taskId);

  Future<ApiResult<ReportOutModel>> report(String id);

  /// The technician's own words (M32). Only the parts given change.
  Future<ApiResult<ReportOutModel>> edit(String id, {String? summary, String? workDone, String? advice});

  /// Writes one part again with AI.
  Future<ApiResult<ReportStartedModel>> regenerate(String id, String section);

  /// "Send to manager": locks the proof and waits for review.
  Future<ApiResult<ReportOutModel>> submit(String id);
}

class ReportsApiRepository implements IReportsApiRepository {
  ReportsApiRepository({required this.provider});

  final IReportsApiProvider provider;

  Map<String, dynamic> _map(dynamic json) => Map<String, dynamic>.from(json as Map);

  @override
  Future<ApiResult<ReportStartedModel>> start(String jobId) =>
      guard(() async => ReportStartedModel.fromJson(_map(await provider.postStart(jobId))));

  @override
  Future<ApiResult<TaskOutModel>> task(String taskId) =>
      guard(() async => TaskOutModel.fromJson(_map(await provider.getTask(taskId))));

  @override
  Future<ApiResult<ReportOutModel>> report(String id) =>
      guard(() async => ReportOutModel.fromJson(_map(await provider.getReport(id))));

  @override
  Future<ApiResult<ReportOutModel>> edit(String id, {String? summary, String? workDone, String? advice}) => guard(
        () async => ReportOutModel.fromJson(
          _map(await provider.patchReport(id, {'summary': ?summary, 'work_done': ?workDone, 'advice': ?advice})),
        ),
      );

  @override
  Future<ApiResult<ReportStartedModel>> regenerate(String id, String section) =>
      guard(() async => ReportStartedModel.fromJson(_map(await provider.postRegenerate(id, section))));

  @override
  Future<ApiResult<ReportOutModel>> submit(String id) =>
      guard(() async => ReportOutModel.fromJson(_map(await provider.postSubmit(id))));
}
