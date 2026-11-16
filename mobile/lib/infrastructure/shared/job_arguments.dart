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
  const PhotoArguments({
    required this.jobId,
    required this.stage,
    this.customer = '',
    this.prompts = const [],
    this.single = false,
    this.place,
  });

  final String jobId;
  final String stage;
  final String customer;

  /// Camera hints from the job's checklists ("Show the clean filter up close").
  final List<ShotPromptModel> prompts;

  /// One photo for a checklist question: the camera closes after the shot and returns the photo's id.
  final bool single;

  /// "4 Lake Road · Room 2", shown on a photo's details.
  final String? place;

  PhotoArguments withStage(String s) =>
      PhotoArguments(jobId: jobId, stage: s, customer: customer, prompts: prompts, single: single, place: place);
}

/// Opens a job's checklists (M24) or one checklist's questions (M25).
class ChecklistArguments {
  const ChecklistArguments({
    required this.jobId,
    this.checklistId,
    this.customer = '',
    this.coverUrl,
    this.equipment,
  });

  final String jobId;
  final String? checklistId;
  final String customer;

  /// The job's picture and "Split AC · Room 2" on the checklist card.
  final String? coverUrl;
  final String? equipment;

  ChecklistArguments open(String id) =>
      ChecklistArguments(jobId: jobId, checklistId: id, customer: customer, coverUrl: coverUrl, equipment: equipment);
}

/// Opens one photo (M23) or the before/after comparison (M22).
class PhotoDetailArguments {
  const PhotoDetailArguments({
    required this.jobId,
    this.evidenceId,
    this.customer = '',
    this.place,
    this.index = 1,
    this.total = 1,
  });

  final String jobId;
  final String? evidenceId;
  final String customer;

  /// "4 Lake Road · Room 2"
  final String? place;

  /// "photo 1 of 3" within its stage.
  final int index;
  final int total;
}
