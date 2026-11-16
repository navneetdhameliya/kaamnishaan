import 'package:flutter/material.dart';

import '../../../../common_widgets/kn_photo_badge.dart';
import '../../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../../theme/kn_app_theme.dart';
import '../../../../theme/kn_tokens.g.dart';

/// One M03 slide: photo with two badges, then the title and text.
class IntroSlide extends StatelessWidget {
  const IntroSlide({
    super.key,
    required this.image,
    required this.topBadge,
    required this.bottomBadge,
    required this.title,
    required this.body,
    required this.dots,
  });

  final String image;
  final Widget topBadge;
  final KnPhotoBadge bottomBadge;
  final String title;
  final String body;
  final Widget dots;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: KnSize.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 328 / 372,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(image, fit: BoxFit.cover),
                  Positioned(left: 16, top: 16, child: topBadge),
                  Positioned(left: 16, bottom: 16, child: bottomBadge),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          dots,
          const SizedBox(height: 20),
          CustomBaseTextWidget(title, style: context.knText.h1),
          const SizedBox(height: KnSize.space8),
          CustomBaseTextWidget(body, style: context.knText.bodyLg, color: context.kn.textSecondary),
          const SizedBox(height: KnSize.space16),
        ],
      ),
    );
  }
}
