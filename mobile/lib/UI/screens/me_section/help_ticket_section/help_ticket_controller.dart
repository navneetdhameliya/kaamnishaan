import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../../infrastructure/data_access_layer/api_repository/support_api_repository.dart';
import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../infrastructure/lang/translation_service.dart';
import '../../../../infrastructure/models/api_models.g.dart';
import '../../../../infrastructure/shared/time_utils.dart';
import '../../../common_widgets/kn_toast.dart';

/// M47 A help request: the conversation with KaamNishaan support, a reply box and "It's sorted".
class HelpTicketController extends GetxController {
  HelpTicketController({
    required this.repository,
    required this.translation,
    String? id,
    DateTime Function()? clock,
  })  : id = id ?? Get.arguments as String,
        _clock = clock ?? DateTime.now;

  final ISupportApiRepository repository;
  final TranslationService translation;
  final String id;
  final DateTime Function() _clock;

  final Rxn<TicketOutModel> ticket = Rxn<TicketOutModel>();
  final RxBool loaded = false.obs;
  final RxBool sending = false.obs;
  final RxBool solving = false.obs;
  final input = TextEditingController();
  final scroll = ScrollController();
  final RxInt _typed = 0.obs;

  @override
  void onInit() {
    super.onInit();
    input.addListener(() => _typed.value++);
    load();
  }

  @override
  void onClose() {
    input.dispose();
    scroll.dispose();
    super.onClose();
  }

  Future<void> load() async {
    final result = await repository.get(id);
    loaded.value = true;
    _take(result.dataOrNull, result.errorOrNull?.message);
  }

  void _take(TicketOutModel? t, String? error) {
    if (t == null) {
      if (error != null) KnToast.error(error);
      return;
    }
    ticket.value = t;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scroll.hasClients) scroll.jumpTo(scroll.position.maxScrollExtent);
    });
  }

  bool get canSend {
    _typed.value;
    return input.text.trim().isNotEmpty && !sending.value;
  }

  bool get solved => ticket.value?.status == 'solved';

  String when(TicketMessageOutModel m) {
    final at = m.createdAt.toLocal();
    final now = _clock();
    final clock = TimeUtils.clock(at, translation.currentCode);
    if (at.year == now.year && at.month == now.month && at.day == now.day) return clock;
    return '${DateFormat('d MMM', translation.currentCode).format(at)}, $clock';
  }

  String get statusNote => switch (ticket.value?.status) {
        'waiting' => LangKeys.helpNoteWaiting.tr,
        'solved' => LangKeys.helpNoteSolved.tr,
        _ => LangKeys.helpNoteOpen.tr,
      };

  Future<void> onSend() async {
    final text = input.text.trim();
    if (text.isEmpty || sending.value) return;
    sending.value = true;
    final result = await repository.reply(id, text);
    sending.value = false;
    if (result.dataOrNull != null) input.clear();
    _take(result.dataOrNull, result.errorOrNull?.message);
  }

  Future<void> onSolve() async {
    if (solving.value) return;
    solving.value = true;
    final result = await repository.solve(id);
    solving.value = false;
    _take(result.dataOrNull, result.errorOrNull?.message);
    if (result.dataOrNull != null) KnToast.success(LangKeys.helpSolvedToast.tr);
  }
}
