import 'package:flutter/material.dart';

import '../commons/behaviour/behaviour.dart';
import '../theme/kn_app_theme.dart';
import '../theme/kn_tokens.g.dart';
import 'kn_back_button.dart';

/// Standard screen frame: canvas background, optional back button, scrolling body and a fixed footer.
class KnPageScaffold extends StatelessWidget {
  const KnPageScaffold({
    super.key,
    required this.body,
    this.footer,
    this.showBack = true,
    this.onBack,
    this.scroll = true,
    this.topAction,
  });

  final Widget body;
  final Widget? footer;
  final bool showBack;
  final VoidCallback? onBack;
  final bool scroll;
  final Widget? topAction;

  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: const EdgeInsets.symmetric(horizontal: KnSize.space16), child: body);
    return Scaffold(
      backgroundColor: context.kn.bgCanvas,
      body: SafeArea(
        bottom: footer == null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showBack || topAction != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(KnSize.space16, 40, KnSize.space16, 0),
                child: Row(
                  children: [
                    if (showBack) KnBackButton(onTap: onBack),
                    const Spacer(),
                    if (topAction != null) topAction!,
                  ],
                ),
              ),
            Expanded(
              child: scroll
                  ? ScrollConfiguration(
                      behavior: const KnScrollBehavior(),
                      child: SingleChildScrollView(child: content),
                    )
                  : content,
            ),
            if (footer != null) footer!,
          ],
        ),
      ),
    );
  }
}
