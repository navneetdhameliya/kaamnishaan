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
}
