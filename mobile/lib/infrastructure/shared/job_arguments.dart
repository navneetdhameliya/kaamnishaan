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

/// Opens Customer details (M18). [name] shows at once, before the customer has loaded.
class CustomerArguments {
  const CustomerArguments({required this.id, required this.name});

  final String id;
  final String name;
}

/// Opens Assign technician (M17). With [jobId] the pick is saved at once; without it (from New job, M16)
/// the screen returns the picked technician. [at] gives the day whose jobs are counted.
class AssignArguments {
  const AssignArguments({required this.customer, required this.title, this.jobId, this.at, this.selectedId});

  final String customer;
  final String title;
  final String? jobId;
  final DateTime? at;
  final String? selectedId;
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

/// Opens the voice recorder (M27), a job's notes (M28) or one note (M29).
class VoiceArguments {
  const VoiceArguments({
    required this.jobId,
    this.customer = '',
    this.noteId,
    this.index = 1,
    this.openListAfter = false,
  });

  final String jobId;
  final String customer;

  /// M29: the note to show, and its number ("Voice note 2").
  final String? noteId;
  final int index;

  /// M27 from the proof screen with no notes yet: after saving, show the notes list (M28).
  final bool openListAfter;

  VoiceArguments note(String id, int index) => VoiceArguments(jobId: jobId, customer: customer, noteId: id, index: index);

  VoiceArguments get record => VoiceArguments(jobId: jobId, customer: customer);
}

/// The job report screens (M31 making / draft / sent, M32 editor).
class ReportArguments {
  const ReportArguments({
    required this.jobId,
    this.customer = '',
    this.reportId,
    this.coverUrl,
    this.photos = 0,
    this.checklists = 0,
    this.notes = 0,
    this.thumbs = const [],
    this.redraft = false,
  });

  final String jobId;
  final String customer;

  /// Set once the report exists.
  final String? reportId;
  final String? coverUrl;

  /// What the report is made from, for "Reading 6 photos…".
  final int photos;
  final int checklists;
  final int notes;
  final List<String> thumbs;

  /// M31 making: write a new draft even when one is already there.
  final bool redraft;

  ReportArguments withReport(String id) => ReportArguments(
        jobId: jobId,
        customer: customer,
        reportId: id,
        coverUrl: coverUrl,
        photos: photos,
        checklists: checklists,
        notes: notes,
        thumbs: thumbs,
      );

  ReportArguments get remake => ReportArguments(
        jobId: jobId,
        customer: customer,
        reportId: reportId,
        coverUrl: coverUrl,
        photos: photos,
        checklists: checklists,
        notes: notes,
        thumbs: thumbs,
        redraft: true,
      );
}
