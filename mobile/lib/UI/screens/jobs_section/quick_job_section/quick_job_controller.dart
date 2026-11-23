import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../../../../infrastructure/commons/constants/app_routes.dart';
import '../../../../infrastructure/data_access_layer/api_repository/jobs_api_repository.dart';
import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../infrastructure/shared/job_arguments.dart';
import '../../../common_widgets/kn_dictation.dart';
import '../../../common_widgets/kn_toast.dart';

/// Quick job (D-18, D-140): a technician's work that wasn't planned. What the work is, who it is for, their
/// phone and address; "Start job" makes the job (given to the technician), starts it and opens the proof
/// steps (M19). Speaking works in the work and customer boxes. No Figma frame: the sign-up form's fields.
class QuickJobController extends GetxController {
  QuickJobController({required this.jobs, required this.dictation, DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final IJobsApiRepository jobs;
  final Dictation dictation;
  final DateTime Function() _clock;

  final work = TextEditingController();
  final customer = TextEditingController();
  final phone = TextEditingController();
  final address = TextEditingController();

  /// A message under a field: work, customer or phone.
  final RxMap<String, String> errors = <String, String>{}.obs;
  final RxBool saving = false.obs;

  /// One job even when "Start job" is tapped twice or sent again after a lost connection.
  final String _clientUuid = const Uuid().v4();

  /// Made but not started (the start failed): a second tap only starts it.
  String? _madeId;

  @override
  void onClose() {
    dictation.cancel();
    for (final c in [work, customer, phone, address]) {
      c.dispose();
    }
    super.onClose();
  }

  void clearError(String field) => errors.remove(field);

  static String? _t(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  bool _valid() {
    errors.clear();
    if (_t(work) == null) errors['work'] = LangKeys.qjWorkNeeded.tr;
    if (_t(customer) == null) errors['customer'] = LangKeys.qjCustomerNeeded.tr;
    return errors.isEmpty;
  }

  /// "Start job": make it, start it, then the proof steps take this screen's place.
  Future<void> onStartTap() async {
    if (saving.value || !_valid()) return;
    saving.value = true;
    var id = _madeId;
    if (id == null) {
      final made = await jobs.create(
        title: _t(work)!,
        scheduledAt: _clock(),
        clientUuid: _clientUuid,
        newCustomer: _t(customer),
        newCustomerPhone: _t(phone),
        address: _t(address),
      );
      final job = made.dataOrNull;
      if (job == null) {
        saving.value = false;
        final e = made.errorOrNull!;
        if (e.code == 'invalid_phone') {
          errors['phone'] = LangKeys.customersPhoneBad.tr;
        } else {
          KnToast.error(e.message);
        }
        return;
      }
      id = _madeId = job.id;
    }
    final started = await jobs.start(id);
    saving.value = false;
    final args = JobArguments(id: id, customer: _t(customer), title: _t(work));
    if (started.dataOrNull == null) {
      // the job is made: it waits on Today, and its page can start it
      KnToast.error(started.errorOrNull!.message);
      await Get.offNamed<void>(RoutesConstants.jobDetailsScreen, arguments: args);
      return;
    }
    await Get.offNamed<void>(RoutesConstants.captureHubScreen, arguments: args);
  }
}
