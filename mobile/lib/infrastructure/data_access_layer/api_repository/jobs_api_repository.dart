import 'package:intl/intl.dart';

import '../../models/api_models.g.dart';
import '../api_providers/jobs_api_provider.dart';
import '../networks/api_result.dart';

/// Which jobs the list shows. Days are in the company's time zone (the server knows it).
class JobQuery {
  const JobQuery({this.date, this.range = 'day', this.unassigned = false, this.search});

  final DateTime? date;

  /// day, week or month
  final String range;
  final bool unassigned;
  final String? search;

  Map<String, dynamic> toQuery() => {
        if (date != null) 'date': DateFormat('yyyy-MM-dd').format(date!),
        'range': range,
        if (unassigned) 'unassigned': true,
        if (search != null && search!.trim().isNotEmpty) 'q': search!.trim(),
        'limit': 100,
      };
}

abstract class IJobsApiRepository {
  Future<ApiResult<JobListModel>> list(JobQuery query);
  Future<ApiResult<JobOutModel>> job(String id);
  Future<ApiResult<JobOutModel>> start(String id, {double? lat, double? lng});
  Future<ApiResult<ProofModel>> proof(String id);

  /// One photo with its notes (M23).
  Future<ApiResult<EvidenceDetailModel>> photo(String evidenceId);
  Future<ApiResult<NoteOutModel>> addNote(String evidenceId, String text);
  Future<ApiResult<void>> deletePhoto(String evidenceId);

  /// M22 "Use in report": keep a before and an after photo side by side.
  Future<ApiResult<PairOutModel>> addPair({required String jobId, required String beforeId, required String afterId, String? subject});

  /// All photos of a job (M21).
  Future<ApiResult<EvidenceListModel>> evidence(String jobId);

  /// Step 3 of a photo upload: say what the uploaded file is. [clientUuid] makes a retry safe.
  /// Returns the photo's id on the server.
  Future<ApiResult<String>> addPhoto({
    required String jobId,
    required String uploadId,
    required String stage,
    required DateTime takenAt,
    required String clientUuid,
    double? lat,
    double? lng,
    String? shotSlot,
  });
}

class JobsApiRepository implements IJobsApiRepository {
  JobsApiRepository({required this.provider});

  final IJobsApiProvider provider;

  Map<String, dynamic> _map(dynamic json) => Map<String, dynamic>.from(json as Map);

  @override
  Future<ApiResult<JobListModel>> list(JobQuery query) =>
      guard(() async => JobListModel.fromJson(_map(await provider.getJobs(query.toQuery()))));

  @override
  Future<ApiResult<JobOutModel>> job(String id) => guard(() async => JobOutModel.fromJson(_map(await provider.getJob(id))));

  @override
  Future<ApiResult<JobOutModel>> start(String id, {double? lat, double? lng}) => guard(
      () async => JobOutModel.fromJson(_map(await provider.postStart(id, {'lat': ?lat, 'lng': ?lng}))));

  @override
  Future<ApiResult<ProofModel>> proof(String id) =>
      guard(() async => ProofModel.fromJson(_map(await provider.getProof(id))));

  @override
  Future<ApiResult<EvidenceDetailModel>> photo(String evidenceId) =>
      guard(() async => EvidenceDetailModel.fromJson(_map(await provider.getEvidenceDetail(evidenceId))));

  @override
  Future<ApiResult<NoteOutModel>> addNote(String evidenceId, String text) =>
      guard(() async => NoteOutModel.fromJson(_map(await provider.postNote(evidenceId, {'text': text.trim()}))));

  @override
  Future<ApiResult<void>> deletePhoto(String evidenceId) => guard(() async {
        await provider.deleteEvidence(evidenceId);
      });

  @override
  Future<ApiResult<PairOutModel>> addPair({
    required String jobId,
    required String beforeId,
    required String afterId,
    String? subject,
  }) =>
      guard(() async => PairOutModel.fromJson(_map(await provider.postPair(jobId, {
            'before_id': beforeId,
            'after_id': afterId,
            'subject': ?subject,
            'use_in_report': true,
          }))));

  @override
  Future<ApiResult<EvidenceListModel>> evidence(String jobId) =>
      guard(() async => EvidenceListModel.fromJson(_map(await provider.getEvidence(jobId))));

  @override
  Future<ApiResult<String>> addPhoto({
    required String jobId,
    required String uploadId,
    required String stage,
    required DateTime takenAt,
    required String clientUuid,
    double? lat,
    double? lng,
    String? shotSlot,
  }) =>
      guard(() async {
        final json = await provider.postEvidence(jobId, {
          'upload_id': uploadId,
          'stage': stage,
          'taken_at': takenAt.toUtc().toIso8601String(),
          'client_uuid': clientUuid,
          'lat': ?lat,
          'lng': ?lng,
          'shot_slot': ?shotSlot,
        });
        return (json as Map)['id'] as String;
      });
}
