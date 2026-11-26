import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../../infrastructure/commons/constants/app_routes.dart';
import '../../../../infrastructure/data_access_layer/api_repository/reports_api_repository.dart';
import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../infrastructure/models/api_models.g.dart';
import '../../../../infrastructure/services/share_service.dart';
import '../../../../infrastructure/shared/job_arguments.dart';
import '../../../common_widgets/kn_toast.dart';

/// M35 Share report: who gets it, by SMS, email or WhatsApp, and the secure link (copy or turn off).
/// With no phone or email saved, one can be typed here and is used for this send.
class ShareReportController extends GetxController {
  ShareReportController({required this.reports, ReportArguments? args, IShareService? share})
      : args = args ?? Get.arguments as ReportArguments,
        _share = share ?? (Get.isRegistered<IShareService>() ? Get.find<IShareService>() : null);

  /// The phone's share sheet for "More" (none in tests: the link is copied instead).
  final IShareService? _share;

  final IReportsApiRepository reports;
  final ReportArguments args;

  static const channelOrder = ['sms', 'email', 'whatsapp'];

  final Rxn<ShareInfoModel> info = Rxn<ShareInfoModel>();
  final Rxn<PdfOutModel> pdf = Rxn<PdfOutModel>();
  final Rxn<ReportOutModel> report = Rxn<ReportOutModel>();
  final RxSet<String> picked = <String>{}.obs;
  final RxBool editing = false.obs;
  final RxBool sending = false.obs;

  /// "Ask for a rating too" (starts from the company setting; off when already asked).
  final RxBool askReview = false.obs;
  final RxBool linkBusy = false.obs;
  final RxnString contactError = RxnString();
  final TextEditingController contact = TextEditingController();

  /// Bumped as the contact is typed, so the tiles follow.
  final RxString typed = ''.obs;

  String get reportId => args.reportId!;

  @override
  void onInit() {
    super.onInit();
    contact.addListener(() => typed.value = contact.text.trim());
    load();
  }

  @override
  void onClose() {
    contact.dispose();
    super.onClose();
  }

  Future<void> load() async {
    final results = await Future.wait([reports.share(reportId), reports.pdf(reportId), reports.report(reportId)]);
    pdf.value = results[1].dataOrNull as PdfOutModel? ?? pdf.value;
    report.value = results[2].dataOrNull as ReportOutModel? ?? report.value;
    final i = results[0].dataOrNull as ShareInfoModel?;
    if (i == null) {
      final e = results[0].errorOrNull!;
      if (!e.isNetwork) KnToast.error(e.message);
      return;
    }
    info.value = i;
    askReview.value = i.reviewAsk == 'on';
    if (picked.isEmpty) {
      final first = channelOrder.firstWhereOrNull(available);
      if (first != null) picked.add(first);
    }
    if (!hasContact) editing.value = true;
  }

  RecipientModel? get recipient => info.value?.recipient;

  String get name => (recipient?.name ?? '').trim().isEmpty ? args.customer : recipient!.name!;

  bool get _typedEmail => typed.value.contains('@');

  String? get _typedPhone => typed.value.isNotEmpty && !_typedEmail ? typed.value : null;

  String? get _typedMail => _typedEmail ? typed.value : null;

  String? get phone => _typedPhone ?? recipient?.phone;

  String? get email => _typedMail ?? recipient?.email;

  bool get hasContact => (recipient?.phone ?? '').isNotEmpty || (recipient?.email ?? '').isNotEmpty;

  /// "+1 555 010 0444", or the email.
  String get contactLine => [phone, email].whereType<String>().where((s) => s.isNotEmpty).join(' · ');

  /// SMS and WhatsApp need a phone, email needs an email; the server can also say no (no credits…).
  bool available(String channel) {
    final fromServer = info.value?.channels.firstWhereOrNull((c) => c.key == channel);
    if (channel == 'email') {
      if (fromServer?.reason == 'email_off') return false; // no email service yet
      return (email ?? '').isNotEmpty || (fromServer?.available ?? false);
    }
    final hasPhone = (phone ?? '').isNotEmpty;
    if (_typedPhone != null) return hasPhone;
    return (fromServer?.available ?? false) && hasPhone;
  }

  /// Why a channel can't be used, in words.
  String? reason(String channel) => switch (info.value?.channels.firstWhereOrNull((c) => c.key == channel)?.reason) {
        'email_off' => LangKeys.shareEmailOff.tr,
        'no_phone' => LangKeys.shareNoPhone.tr,
        'no_email' => LangKeys.shareNoEmail.tr,
        _ => null,
      };

  void onChannelTap(String channel) {
    if (!available(channel)) {
      if (!hasContact && typed.value.isEmpty) {
        editing.value = true;
        contactError.value = LangKeys.shareNoContact.tr;
      } else {
        KnToast.info(reason(channel) ?? LangKeys.shareNoContact.tr);
      }
      return;
    }
    picked.contains(channel) ? picked.remove(channel) : picked.add(channel);
  }

  void onEditContactTap() => editing.toggle();

  void onContactChanged(String _) {
    contactError.value = null;
    picked.removeWhere((c) => !available(c));
    if (picked.isEmpty) {
      final first = channelOrder.firstWhereOrNull(available);
      if (first != null) picked.add(first);
    }
  }

  // ---- PDF and link --------------------------------------------------------------------------

  int get pages => pdf.value?.pages ?? 1;

  String get subtitle => '${args.customer} · #${report.value?.number ?? ''}';

  /// "PDF · 2.4 MB · approved by Priya"
  String get pdfMeta {
    final by = (report.value?.approvedBy?.name ?? '').split(' ').first;
    return by.isEmpty
        ? LangKeys.sharePdfMetaPlain.trParams({'size': size})
        : LangKeys.sharePdfMeta.trParams({'size': size, 'name': by});
  }

  /// "AR" for "Dr. Anita Rao": titles like "Dr." are skipped.
  String get initials {
    final words = name.split(' ').where((w) => w.isNotEmpty && !w.endsWith('.')).toList();
    if (words.isEmpty) return '';
    return (words.first[0] + (words.length > 1 ? words.last[0] : '')).toUpperCase();
  }

  /// "2.4 MB"
  String get size {
    final b = pdf.value?.size ?? 0;
    if (b <= 0) return '';
    if (b < 1024 * 1024) return '${(b / 1024).round()} KB';
    return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  ShareLinkOutModel? get link {
    final l = info.value?.link;
    return l != null && l.status == 'active' ? l : null;
  }

  /// "kn.app/r/7GX2-QK" without the https:// part.
  String get linkText => (link?.url ?? '').replaceFirst(RegExp('^https?://'), '');

  Future<ShareLinkOutModel?> _ensureLink() async {
    if (link != null) return link;
    linkBusy.value = true;
    final result = await reports.createLink(reportId);
    linkBusy.value = false;
    final l = result.dataOrNull;
    if (l == null) {
      KnToast.error(result.errorOrNull!.message);
      return null;
    }
    await load();
    return l;
  }

  Future<void> onCopyTap() async {
    final l = await _ensureLink();
    if (l == null) return;
    await Clipboard.setData(ClipboardData(text: l.url));
    KnToast.success(LangKeys.shareCopied.tr);
  }

  /// "More": the phone's share sheet with the report link, for any other app.
  Future<void> onMoreTap() async {
    final share = _share;
    if (share == null) return onCopyTap();
    final l = await _ensureLink();
    if (l == null) return;
    await share.shareText(LangKeys.shareMoreText.trParams({'customer': name, 'url': l.url}));
  }

  Future<void> onTurnOffTap() async {
    final l = link;
    if (l == null) return;
    linkBusy.value = true;
    final result = await reports.revokeLink(l.id);
    linkBusy.value = false;
    if (!result.isSuccess) return KnToast.error(result.errorOrNull!.message);
    KnToast.success(LangKeys.shareTurnedOff.tr);
    await load();
  }

  // ---- send ----------------------------------------------------------------------------------

  /// A rating was already asked for this job.
  bool get reviewAsked => info.value?.reviewAsk == 'asked';

  void onAskReviewChanged(bool v) {
    if (!reviewAsked) askReview.value = v;
  }

  bool get canSend => picked.isNotEmpty && (info.value?.canShare ?? false);

  Future<void> onSendTap() async {
    if (picked.isEmpty) {
      if (!hasContact && typed.value.isEmpty) contactError.value = LangKeys.shareNoContact.tr;
      return KnToast.info(LangKeys.sharePickChannel.tr);
    }
    sending.value = true;
    final result = await reports.send(
      reportId,
      channels: [for (final c in channelOrder) if (picked.contains(c)) c],
      phone: _typedPhone,
      email: _typedMail,
      // empty = the company setting, so it is sent only when changed here
      askForReview: reviewAsked || askReview.value == (info.value?.reviewAsk == 'on') ? null : askReview.value,
    );
    sending.value = false;
    final i = result.dataOrNull;
    if (i == null) {
      final e = result.errorOrNull!;
      if (e.fields.isNotEmpty) contactError.value = e.message;
      return KnToast.error(e.message);
    }
    info.value = i;
    KnToast.success(LangKeys.shareSent.trParams({'name': name}));
    Get.offAllNamed<void>(RoutesConstants.homeScreen);
  }
}
