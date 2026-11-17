import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../../infrastructure/data_access_layer/api_repository/company_api_repository.dart';
import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../infrastructure/lang/translation_service.dart';
import '../../../../infrastructure/models/api_models.g.dart';
import '../../../../infrastructure/services/config_service.dart';
import '../../../../infrastructure/services/session_service.dart';
import '../../../../infrastructure/shared/text_utils.dart';
import '../../../common_widgets/kn_toast.dart';

/// M40 Invite person: role, mobile number, name and SMS language, with the SMS they will get.
/// A number already in the team says who it is (Figma 77:2084). Opened with 'manager' as the
/// argument it starts on Manager; otherwise on Technician.
class InviteController extends GetxController {
  InviteController({
    required this.company,
    required this.config,
    required this.session,
    required this.translation,
    String? role,
  }) : role = (role ?? (Get.arguments is String ? Get.arguments as String : 'technician')).obs;

  final ICompanyApiRepository company;
  final ConfigService config;
  final SessionService session;
  final TranslationService translation;

  /// technician or manager
  final RxString role;
  late final Rx<CountryOutModel> country = config.defaultCountry.obs;
  final TextEditingController phone = TextEditingController();
  final RxString digits = ''.obs;
  final TextEditingController name = TextEditingController();
  final FocusNode nameFocus = FocusNode();
  final RxString nameText = ''.obs;
  late final RxString smsLanguage = (session.me.value?.company?.reportLanguage ?? translation.currentCode).obs;
  final RxString preview = ''.obs;
  final RxBool tried = false.obs;
  final RxBool sending = false.obs;

  /// Set when the number is already in the team: their name, and whether they joined.
  final RxnString existingName = RxnString();
  final RxBool existingJoined = false.obs;
  final RxnString serverError = RxnString();

  static const _lengths = {'+91': 10, '+1': 10, '+52': 10, '+34': 9, '+33': 9};

  @override
  void onInit() {
    super.onInit();
    loadPreview();
  }

  @override
  void onClose() {
    phone.dispose();
    name.dispose();
    nameFocus.dispose();
    super.onClose();
  }

  Future<void> loadPreview() async {
    final text = (await company.invitePreview()).dataOrNull;
    if (text != null) preview.value = text;
  }

  // ---- what it shows -----------------------------------------------------------------------

  bool get canInviteManager => session.me.value?.role == 'owner';

  int get requiredDigits => _lengths[country.value.dialCode] ?? 10;

  bool get phoneValid {
    final n = digits.value.length;
    return _lengths.containsKey(country.value.dialCode) ? n == requiredDigits : n >= 6 && n <= 14;
  }

  String get e164 => '${country.value.dialCode}${digits.value}';

  /// The red line under the number: already in the team, a server message, or a wrong length.
  String? get phoneError {
    final who = existingName.value;
    if (who != null) {
      return (existingJoined.value ? LangKeys.inviteInTeam : LangKeys.inviteAlreadyInvited).trParams({'name': who});
    }
    if (serverError.value != null) return serverError.value;
    if (tried.value && !phoneValid) return LangKeys.authPhoneInvalid.trParams({'digits': '$requiredDigits'});
    return null;
  }

  String? get nameError => tried.value && nameText.value.trim().isEmpty ? LangKeys.inviteNameMissing.tr : null;

  /// "See Carlos in Team"
  String? get seeInTeam {
    final who = existingName.value;
    return who == null ? null : LangKeys.inviteSeeInTeam.trParams({'name': TextUtils.firstName(who)});
  }

  bool get canSend => existingName.value == null;

  String get languageName => TranslationService.byCode(smsLanguage.value).nativeName;

  /// "Arjun will get this SMS"
  String get willGet {
    final n = nameText.value.trim();
    return n.isEmpty ? LangKeys.inviteTheyGet.tr : LangKeys.inviteWillGet.trParams({'name': TextUtils.firstName(n)});
  }

  String get inviter => session.me.value?.name ?? '';

  String get inviterLine {
    final r = switch (session.me.value?.role) {
      'owner' => LangKeys.roleOwner.tr,
      'manager' => LangKeys.roleManager.tr,
      _ => LangKeys.roleTechnician.tr,
    };
    return '$inviter · $r';
  }

  // ---- actions -----------------------------------------------------------------------------

  void onRoleTap(String r) => role.value = r;

  void onCountrySelected(CountryOutModel c) {
    country.value = c;
    _numberChanged();
    Get.back<void>();
  }

  void onPhoneChanged(String v) {
    digits.value = v.replaceAll(RegExp(r'\D'), '');
    _numberChanged();
  }

  void _numberChanged() {
    existingName.value = null;
    serverError.value = null;
  }

  void onNameChanged(String v) => nameText.value = v;

  void onNameMicTap() => nameFocus.requestFocus();

  void onLanguagePicked(String code) {
    smsLanguage.value = code;
    Get.back<void>();
  }

  /// "See Carlos in Team": back to the team list.
  void onSeeInTeamTap() => Get.back<void>();

  Future<void> onSendTap() async {
    tried.value = true;
    if (!phoneValid || nameText.value.trim().isEmpty || !canSend || sending.value) return;
    sending.value = true;
    final result = await company.invite(
      phone: e164,
      name: nameText.value,
      role: role.value,
      smsLanguage: smsLanguage.value,
    );
    sending.value = false;
    final out = result.dataOrNull;
    if (out == null) {
      final e = result.errorOrNull!;
      if (e.code == 'phone_in_team') {
        final who = (e.details['existing_member'] as Map?) ?? const {};
        existingJoined.value = who['status'] == 'active';
        existingName.value = (who['name'] as String?)?.trim().isNotEmpty == true ? who['name'] as String : e164;
      } else if (e.fields['phone'] != null) {
        serverError.value = e.message;
      } else {
        KnToast.error(e.message);
      }
      return;
    }
    KnToast.success(LangKeys.inviteSent.trParams({'name': TextUtils.firstName(out.name)}));
    Get.back<bool>(result: true);
  }
}
