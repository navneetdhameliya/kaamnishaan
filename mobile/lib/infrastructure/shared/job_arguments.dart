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
