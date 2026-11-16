import 'package:get/get.dart';

import '../../../../infrastructure/commons/constants/app_routes.dart';
import '../../../../infrastructure/data_access_layer/api_repository/checklists_api_repository.dart';
import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../infrastructure/lang/translation_service.dart';
import '../../../../infrastructure/models/api_models.g.dart';
import '../../../../infrastructure/services/photo_queue_service.dart';
import '../../../../infrastructure/shared/job_arguments.dart';
import '../../../../infrastructure/shared/time_utils.dart';
import '../../../common_widgets/kn_toast.dart';

/// M24 Checklists: the job's lists, how far each one is, and the one to do now.
class ChecklistsController extends GetxController {
  ChecklistsController({
    required this.checklists,
    required this.queue,
    required this.translation,
    ChecklistArguments? args,
  }) : args = args ?? Get.arguments as ChecklistArguments;

  final IChecklistsApiRepository checklists;
  final PhotoQueueService queue;
  final TranslationService translation;
  final ChecklistArguments args;

  final RxList<JobChecklistItemModel> lists = <JobChecklistItemModel>[].obs;
  final RxBool loaded = false.obs;
  Worker? _sentWorker;

  @override
  void onInit() {
    super.onInit();
    load();
    _sentWorker = ever(queue.answersSent, (_) => load());
  }

  @override
  void onClose() {
    _sentWorker?.dispose();
    super.onClose();
  }

  Future<void> load() async {
    final result = await checklists.forJob(args.jobId);
    loaded.value = true;
    final data = result.dataOrNull;
    if (data != null) {
      lists.assignAll(data.data);
    } else if (!result.errorOrNull!.isNetwork) {
      KnToast.error(result.errorOrNull!.message);
    }
  }

  /// Answers given on the phone count before they reach the server.
  int answeredOf(JobChecklistItemModel c) {
    final waiting = queue.answersFor(c.id).length;
    final n = c.answered + waiting;
    return n > c.total ? c.total : n;
  }

  bool isDone(JobChecklistItemModel c) => c.status == 'done' || (c.total > 0 && answeredOf(c) >= c.total);

  /// The list to do now: the first one not done.
  JobChecklistItemModel? get active => lists.firstWhereOrNull((c) => !isDone(c));

  String meta(JobChecklistItemModel c) => c.minutes == null
      ? LangKeys.checklistMetaShort.trParams({'count': '${c.total}'})
      : LangKeys.checklistMeta.trParams({'count': '${c.total}', 'minutes': '${c.minutes}'});

  String doneLine(JobChecklistItemModel c) {
    final at = c.completedAt;
    return at == null
        ? LangKeys.hubOf.trParams({'done': '${answeredOf(c)}', 'total': '${c.total}'})
        : LangKeys.checklistDoneAt.trParams({
            'done': '${c.total}',
            'total': '${c.total}',
            'time': TimeUtils.clock(at, translation.currentCode),
          });
  }

  String get startLabel {
    final a = active;
    if (a == null) return '';
    return (answeredOf(a) == 0 ? LangKeys.checklistStart : LangKeys.checklistContinue).trParams({'name': a.name});
  }

  Future<void> open(JobChecklistItemModel c) async {
    await Get.toNamed(RoutesConstants.checklistQuestionScreen, arguments: args.open(c.id));
    load();
  }

  void onStartTap() {
    final a = active;
    if (a != null) open(a);
  }
}
