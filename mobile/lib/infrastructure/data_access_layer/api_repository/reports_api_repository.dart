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

  /// The review queue (M30, managers): reports in [statuses], oldest waiting first.
  Future<ApiResult<ReportListModel>> list({List<String>? statuses, String? period, String? q, String? cursor});

  /// M33 Approve: the job is done and the PDF starts building.
  Future<ApiResult<ReportOutModel>> approve(String id);

  /// M33 Ask for changes: [reasons] from missing_photos, wrong_details, unclear_text,
  /// failed_check_not_explained, other (needs a note).
  Future<ApiResult<ReportOutModel>> requestChanges(String id, {required List<String> reasons, String? note});

  /// M34: the PDF, or "building".
  Future<ApiResult<PdfOutModel>> pdf(String id);

  /// M35: who it goes to, how, and the secure link.
  Future<ApiResult<ShareInfoModel>> share(String id);

  /// A secure link for copying (or a channel); renews an existing one for 30 more days.
  Future<ApiResult<ShareLinkOutModel>> createLink(String id, {String channel = 'copy'});

  /// "Turn off link".
  Future<ApiResult<void>> revokeLink(String linkId);

  /// "Send to customer" by the chosen [channels].
  Future<ApiResult<ShareInfoModel>> send(
    String id, {
    required List<String> channels,
    String? name,
    String? phone,
    String? email,
    bool? askForReview,
  });
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

  @override
  Future<ApiResult<ReportListModel>> list({List<String>? statuses, String? period, String? q, String? cursor}) =>
      guard(
        () async => ReportListModel.fromJson(
          _map(
            await provider.getReports({
              'status': ?statuses,
              'period': ?period,
              'q': ?q,
              'cursor': ?cursor,
              'limit': 50,
            }),
          ),
        ),
      );

  @override
  Future<ApiResult<ReportOutModel>> approve(String id) =>
      guard(() async => ReportOutModel.fromJson(_map(await provider.postApprove(id))));

  @override
  Future<ApiResult<ReportOutModel>> requestChanges(String id, {required List<String> reasons, String? note}) =>
      guard(
        () async => ReportOutModel.fromJson(
          _map(await provider.postChanges(id, {'reasons': reasons, 'note': ?note})),
        ),
      );

  @override
  Future<ApiResult<PdfOutModel>> pdf(String id) =>
      guard(() async => PdfOutModel.fromJson(_map(await provider.getPdf(id))));

  @override
  Future<ApiResult<ShareInfoModel>> share(String id) =>
      guard(() async => ShareInfoModel.fromJson(_map(await provider.getShare(id))));

  @override
  Future<ApiResult<ShareLinkOutModel>> createLink(String id, {String channel = 'copy'}) =>
      guard(() async => ShareLinkOutModel.fromJson(_map(await provider.postShareLink(id, {'channel': channel}))));

  @override
  Future<ApiResult<void>> revokeLink(String linkId) => guard(() async {
        await provider.deleteShareLink(linkId);
      });

  @override
  Future<ApiResult<ShareInfoModel>> send(
    String id, {
    required List<String> channels,
    String? name,
    String? phone,
    String? email,
    bool? askForReview,
  }) =>
      guard(
        () async => ShareInfoModel.fromJson(
          _map(
            await provider.postSend(id, {
              'channels': channels,
              'name': ?name,
              'phone': ?phone,
              'email': ?email,
              'ask_for_review': ?askForReview,
            }),
          ),
        ),
      );
}
