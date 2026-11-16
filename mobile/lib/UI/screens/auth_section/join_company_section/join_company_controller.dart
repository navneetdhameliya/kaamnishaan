import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../infrastructure/commons/constants/app_routes.dart';
import '../../../../infrastructure/data_access_layer/api_repository/auth_api_repository.dart';
import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../infrastructure/lang/translation_service.dart';
import '../../../../infrastructure/models/api_models.g.dart';
import '../../../../infrastructure/services/config_service.dart';
import '../../../../infrastructure/services/session_service.dart';
import '../../../../infrastructure/services/speech_service.dart';
import '../../../common_widgets/kn_toast.dart';

enum JoinState { loading, invite, expired, none }

/// M10: a technician joins the company that invited their phone number.
class JoinCompanyController extends GetxController {
  JoinCompanyController({
    required this.repository,
    required this.session,
    required this.config,
    required this.speech,
    required this.translation,
  });

  final IAuthApiRepository repository;
  final SessionService session;
  final ConfigService config;
  final ISpeechService speech;
  final TranslationService translation;

  final Rx<JoinState> state = JoinState.loading.obs;
  final Rxn<MyInviteModel> invite = Rxn<MyInviteModel>();
  final RxBool apiCallLoader = false.obs;

  @override
  void onInit() {
    super.onInit();
    _pickInvite(session.invites);
  }

  void _pickInvite(List<MyInviteModel> open) {
    if (open.isNotEmpty) {
      invite.value = open.first;
      state.value = JoinState.invite;
    } else {
      callMyInvitesAPI();
    }
  }

  /// No open invite: look for an expired one to explain why, else show "no invite".
  Future<void> callMyInvitesAPI() async {
    state.value = JoinState.loading;
    final list = (await repository.myInvites()).dataOrNull?.data ?? const <MyInviteModel>[];
    final pending = list.where((i) => i.status == 'pending').toList();
    if (pending.isNotEmpty) {
      invite.value = pending.first;
      state.value = JoinState.invite;
    } else if (list.isNotEmpty) {
      invite.value = list.first;
      state.value = JoinState.expired;
    } else {
      invite.value = null;
      state.value = JoinState.none;
    }
  }

  String get companyName => invite.value?.company.name ?? '';

  String get companyMeta {
    final c = invite.value?.company;
    if (c == null) return '';
    final trade = config.trades.firstWhereOrNull((t) => t.key == c.trade)?.name ?? c.trade;
    final country = config.countries.firstWhereOrNull((x) => x.code == c.country)?.name ?? c.country;
    return [if (trade != null && trade.isNotEmpty) trade, country].join(' · ');
  }

  String get sentAgo {
    final sent = invite.value?.sentAt;
    if (sent == null) return '';
    final days = DateTime.now().difference(sent).inDays;
    return days < 1 ? LangKeys.timeToday.tr : LangKeys.timeDaysAgo.trParams({'count': '$days'});
  }

  String get expiredOn {
    final at = invite.value?.expiresAt;
    return at == null ? '' : DateFormat.MMMEd(translation.currentCode).format(at.toLocal());
  }

  String get managerName => invite.value?.invitedBy.name ?? '';

  bool get canCallManager => (invite.value?.invitedBy.phone ?? '').isNotEmpty;

  Future<void> callAcceptInviteAPI() async {
    final current = invite.value;
    if (current == null) return;
    apiCallLoader.value = true;
    final result = await repository.acceptInvite(current.id);
    if (result.isSuccess) {
      final route = await session.refreshAndRoute();
      apiCallLoader.value = false;
      Get.offAllNamed(route);
      return;
    }
    apiCallLoader.value = false;
    final error = result.errorOrNull!;
    if (error.code == 'invite_expired' || error.code == 'invite_revoked') {
      state.value = JoinState.expired;
    } else {
      KnToast.error(error.message);
    }
  }

  Future<void> callDeclineInviteAPI() async {
    final current = invite.value;
    if (current == null) return;
    apiCallLoader.value = true;
    final result = await repository.declineInvite(current.id);
    apiCallLoader.value = false;
    if (!result.isSuccess) return KnToast.error(result.errorOrNull!.message);
    session.invites.removeWhere((i) => i.id == current.id);
    _pickInvite(session.invites);
  }

  Future<void> onTryAgainTap() async {
    await session.refreshAndRoute();
    _pickInvite(session.invites);
  }

  Future<void> onCallManagerTap() async {
    final phone = invite.value?.invitedBy.phone;
    if (phone == null || phone.isEmpty) return;
    await launchUrl(Uri(scheme: 'tel', path: phone));
  }

  void onHearTap() => speech.speak(
        '${LangKeys.joinAskManager.tr}. ${LangKeys.joinAskManagerBody.trParams({'name': managerName})}',
        languageCode: translation.currentCode,
      );

  /// Back from here means "wrong number": sign out and start again.
  Future<void> onBackTap() async {
    await session.clear();
    Get.offAllNamed(RoutesConstants.phoneScreen);
  }
}
