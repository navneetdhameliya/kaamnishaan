import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../../infrastructure/commons/constants/app_routes.dart';
import '../../../../infrastructure/data_access_layer/api_repository/support_api_repository.dart';
import '../../../../infrastructure/lang/translation_service.dart';
import '../../../../infrastructure/models/api_models.g.dart';
import '../../../../infrastructure/shared/time_utils.dart';
import '../../../common_widgets/kn_toast.dart';

/// M47 Help: this person's requests to KaamNishaan support, latest activity first.
class HelpController extends GetxController {
  HelpController({required this.repository, required this.translation, DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final ISupportApiRepository repository;
  final TranslationService translation;
  final DateTime Function() _clock;

  final RxList<TicketOutModel> items = <TicketOutModel>[].obs;
  final RxBool loaded = false.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    final result = await repository.list();
    loaded.value = true;
    final list = result.dataOrNull;
    if (list == null) {
      final e = result.errorOrNull!;
      if (!e.isNetwork) KnToast.error(e.message);
      return;
    }
    items.assignAll(list);
  }

  /// Requests where support has answered and is waiting on this person.
  int get waitingOnMe => items.where((t) => t.status == 'waiting').length;

  /// The clock time today, else the date.
  String when(TicketOutModel t) {
    final at = t.lastMessageAt.toLocal();
    final now = _clock();
    if (at.year == now.year && at.month == now.month && at.day == now.day) {
      return TimeUtils.clock(at, translation.currentCode);
    }
    return DateFormat('d MMM', translation.currentCode).format(at);
  }

  Future<void> onNew() async {
    await Get.toNamed(RoutesConstants.helpNewScreen);
    await load();
  }

  Future<void> onOpen(TicketOutModel t) async {
    await Get.toNamed(RoutesConstants.helpTicketScreen, arguments: t.id);
    await load();
  }
}
