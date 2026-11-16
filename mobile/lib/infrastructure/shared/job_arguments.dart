import '../models/api_models.g.dart';

/// Opens a job screen. [customer] and [title] show at once, before the job has loaded.
class JobArguments {
  const JobArguments({required this.id, this.customer, this.title});

  factory JobArguments.of(JobListItemModel job) =>
      JobArguments(id: job.id, customer: job.customer.name, title: job.title);

  final String id;
  final String? customer;
  final String? title;
}

/// Opens the camera (M20) or the photos (M21) of a job, for one stage (before, during, after).
class PhotoArguments {
  const PhotoArguments({required this.jobId, required this.stage, this.customer = '', this.prompts = const []});

  final String jobId;
  final String stage;
  final String customer;

  /// Camera hints from the job's checklists ("Show the clean filter up close").
  final List<ShotPromptModel> prompts;

  PhotoArguments withStage(String s) => PhotoArguments(jobId: jobId, stage: s, customer: customer, prompts: prompts);
}
