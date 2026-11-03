import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/theme/kn_theme.dart';
import '../core/theme/kn_tokens.g.dart';

abstract final class Routes {
  static const home = '/';
}

abstract final class AppPages {
  static final pages = [GetPage(name: Routes.home, page: () => const _Placeholder())];
}

/// Step 0 placeholder that proves tokens, fonts and translations are wired.
class _Placeholder extends StatelessWidget {
  const _Placeholder();
  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(KnSize.space24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('app.name'.tr, style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: KnSize.space8),
              Text('app.tagline'.tr, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: kn.textSecondary)),
              const Spacer(),
              FilledButton(onPressed: () {}, child: Text('common.continue'.tr)),
            ],
          ),
        ),
      ),
    );
  }
}
