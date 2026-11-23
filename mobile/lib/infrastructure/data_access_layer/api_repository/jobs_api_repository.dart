import 'package:dio/dio.dart' show ListFormat, ListParam;
import 'package:intl/intl.dart';

import '../../models/api_models.g.dart';
import '../api_providers/jobs_api_provider.dart';
import '../networks/api_result.dart';

/// Which jobs the list shows. Days are in the company's time zone (the server knows it).
class JobQuery {
  const JobQuery({
    this.date,
    this.range = 'day',
    this.unassigned = false,
    this.search,
    this.statuses = const [],
    this.assignee,
  });

  final DateTime? date;

  /// day, week or month
  final String range;
  final bool unassigned;
  final String? search;

  /// Only jobs in these states (the filters sheet); empty: all.
  final List<String> statuses;

  /// Only this technician's jobs (managers).
  final String? assignee;

  Map<String, dynamic> toQuery() => {
        if (date != null) 'date': DateFormat('yyyy-MM-dd').format(date!),
        'range': range,
        if (unassigned) 'unassigned': true,
        if (search != null && search!.trim().isNotEmpty) 'q': search!.trim(),
        if (statuses.isNotEmpty) 'status': statuses,
        'assignee': ?assignee,
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

  /// M16 New job. [customerId] picks a known customer; otherwise [newCustomer] names a new one.
  /// [address] is typed: the server keeps it as the customer's site (an existing one when it matches).
  Future<ApiResult<JobOutModel>> create({
    required String title,
    required DateTime scheduledAt,
    required String clientUuid,
    String? customerId,
    String? newCustomer,
    String? newCustomerPhone,
    String? address,
    String? technicianId,
    List<String> checklistIds = const [],
  });

  /// M17 Who can do the job, with their jobs that day. Before the job exists, [at] gives the day.
  Future<ApiResult<AssignableListModel>> technicians({String? jobId, DateTime? at});

  /// M17 on a saved job: give it to [technicianId] (null takes it back).
  Future<ApiResult<JobOutModel>> assign(String jobId, String? technicianId);

  /// Cancels a job that isn't finished; the [reason] goes on its timeline.
  Future<ApiResult<JobOutModel>> cancel(String jobId, String reason);

  /// Deletes a job nobody has started.
  Future<ApiResult<void>> delete(String jobId);

  /// Earlier jobs on this job's machine, newest first (whoever did them).
  Future<ApiResult<JobListModel>> equipmentHistory(String jobId);

  /// "Not sure? Ask your manager": a message to the office about [question], with the technician's [note].
  Future<ApiResult<void>> askManager(String jobId, {required String question, String? note});
}

class JobsApiRepository implements IJobsApiRepository {
  JobsApiRepository({required this.provider});

  final IJobsApiProvider provider;

  Map<String, dynamic> _map(dynamic json) => Map<String, dynamic>.from(json as Map);

  @override
  Future<ApiResult<JobListModel>> list(JobQuery query) =>
      guard(() async => JobListModel.fromJson(_map(await provider.getJobs(_wire(query.toQuery())))));

  /// Several states go as status=a&status=b (what the server reads), whatever Dio's default is.
  static Map<String, dynamic> _wire(Map<String, dynamic> q) => {
        for (final e in q.entries) e.key: e.value is List<String> ? ListParam<String>(e.value as List<String>, ListFormat.multi) : e.value,
      };

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

  @override
  Future<ApiResult<JobOutModel>> create({
    required String title,
    required DateTime scheduledAt,
    required String clientUuid,
    String? customerId,
    String? newCustomer,
    String? newCustomerPhone,
    String? address,
    String? technicianId,
    List<String> checklistIds = const [],
  }) {
    final typed = address?.trim();
    return guard(() async => JobOutModel.fromJson(_map(await provider.postJob({
          'title': title.trim(),
          'scheduled_at': scheduledAt.toUtc().toIso8601String(),
          'client_uuid': clientUuid,
          'customer_id': ?customerId,
          if (customerId == null)
            'customer': {
              'name': newCustomer?.trim(),
              if (typed != null && typed.isNotEmpty) 'address': typed,
              if (newCustomerPhone != null && newCustomerPhone.trim().isNotEmpty) 'phone': newCustomerPhone.trim(),
            },
          if (customerId != null && typed != null && typed.isNotEmpty) 'address': typed,
          'assigned_to': ?technicianId,
          'checklist_template_ids': checklistIds,
        }))));
  }

  @override
  Future<ApiResult<AssignableListModel>> technicians({String? jobId, DateTime? at}) => guard(
        () async => AssignableListModel.fromJson(_map(await provider.getTechnicians(
              jobId: jobId,
              query: {if (jobId == null && at != null) 'at': at.toUtc().toIso8601String()},
            ))),
      );

  @override
  Future<ApiResult<JobOutModel>> assign(String jobId, String? technicianId) => guard(
        () async => JobOutModel.fromJson(_map(await provider.postAssign(jobId, {'technician_id': technicianId}))),
      );

  @override
  Future<ApiResult<JobOutModel>> cancel(String jobId, String reason) =>
      guard(() async => JobOutModel.fromJson(_map(await provider.postCancel(jobId, {'reason': reason}))));

  @override
  Future<ApiResult<void>> delete(String jobId) => guard(() async {
        await provider.deleteJob(jobId);
      });

  @override
  Future<ApiResult<JobListModel>> equipmentHistory(String jobId) =>
      guard(() async => JobListModel.fromJson(_map(await provider.getEquipmentHistory(jobId))));

  @override
  Future<ApiResult<void>> askManager(String jobId, {required String question, String? note}) => guard(() async {
        await provider.postAskManager(jobId, {
          'question': question,
          if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
        });
      });
}
