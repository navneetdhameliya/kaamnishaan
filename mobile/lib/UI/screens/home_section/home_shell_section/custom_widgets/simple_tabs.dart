import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../../infrastructure/services/session_service.dart';
import '../../../../../infrastructure/shared/text_utils.dart';
import '../../../../common_widgets/kn_custom_button.dart';
import '../../../../common_widgets/kn_initials_avatar.dart';
import '../../../../common_widgets/kn_page_scaffold.dart';
import '../../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../../theme/kn_app_theme.dart';
import '../../../../theme/kn_tokens.g.dart';

/// A tab whose screens come in a later step (Jobs M14, Reports M30): its name and a short note.
class ComingSoonTab extends StatelessWidget {
  const ComingSoonTab({super.key, required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    return KnPageScaffold(
      showBack: false,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: KnSize.space48),
          CustomBaseTextWidget(title, style: context.knText.h1),
          const SizedBox(height: KnSize.space24),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: kn.bgSubtle, shape: BoxShape.circle),
            child: Icon(icon, size: 32, color: kn.textSecondary),
          ),
          const SizedBox(height: KnSize.space16),
          CustomBaseTextWidget(LangKeys.commonComingSoon.tr, style: context.knText.bodyLg, color: kn.textSecondary),
          const SizedBox(height: 112),
        ],
      ),
    );
  }
}

/// Me / Profile for now: photo, name, role and company, and Log out (M37 comes later).
class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key, required this.title, required this.onLogout});

  final String title;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    final me = Get.find<SessionService>().me.value;
    final role = switch (me?.role) {
      'owner' => LangKeys.roleOwner.tr,
      'manager' => LangKeys.roleManager.tr,
      _ => LangKeys.roleTechnician.tr,
    };
    final company = me?.company?.name;
    return KnPageScaffold(
      showBack: false,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: KnSize.space48),
          CustomBaseTextWidget(title, style: text.h1),
          const SizedBox(height: KnSize.space24),
          Row(
            children: [
              KnInitialsAvatar(initials: TextUtils.initials(me?.name ?? ''), url: me?.avatarUrl, size: 64),
              const SizedBox(width: KnSize.space16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomBaseTextWidget(me?.name ?? '', style: text.h3),
                    CustomBaseTextWidget(
                      company == null ? role : LangKeys.dashRoleCompany.trParams({'role': role, 'company': company}),
                      style: text.body,
                      color: kn.textSecondary,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: KnSize.space32),
          KnCustomButton(
            key: const ValueKey('log-out'),
            text: LangKeys.commonLogOut.tr,
            icon: LucideIcons.logOut,
            variant: KnButtonVariant.secondary,
            onTap: onLogout,
          ),
          const SizedBox(height: 112),
        ],
      ),
    );
  }
}
