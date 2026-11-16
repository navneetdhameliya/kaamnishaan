import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../common_widgets/custom_inkwell.dart';
import '../../../../common_widgets/kn_custom_button.dart';
import '../../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../../theme/kn_app_theme.dart';
import '../../../../theme/kn_tokens.g.dart';

/// M25 big answer card: a round icon and a word ("Yes", "No"). [good] picks green or red when chosen.
class BigAnswerCard extends StatelessWidget {
  const BigAnswerCard({
    super.key,
    required this.label,
    required this.good,
    required this.selected,
    required this.onTap,
    this.enabled = true,
  });

  final String label;
  final bool good;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final color = good ? kn.statusSuccess : kn.statusDanger;
    final soft = good ? kn.statusSuccessBg : kn.statusDangerBg;
    final radius = BorderRadius.circular(KnSize.radiusLg);
    return CustomInkWell(
      onTap: enabled ? onTap : null,
      borderRadius: radius,
      semanticLabel: label,
      child: Ink(
        height: 112,
        decoration: BoxDecoration(
          color: selected ? soft : kn.bgSurface,
          borderRadius: radius,
          border: Border.all(color: selected ? color : kn.borderDefault, width: selected ? 2 : 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: selected ? color : soft, shape: BoxShape.circle),
              child: Icon(good ? LucideIcons.check : LucideIcons.x, size: 22, color: selected ? KnPrimitive.cream50 : color),
            ),
            const SizedBox(height: 10),
            CustomBaseTextWidget(label, style: context.knText.h3),
          ],
        ),
      ),
    );
  }
}

/// M25 signature: draw with a finger, then save it as a picture.
class SignaturePad extends StatefulWidget {
  const SignaturePad({super.key, required this.onSave, this.saving = false});

  final ValueChanged<Uint8List> onSave;
  final bool saving;

  @override
  State<SignaturePad> createState() => _SignaturePadState();
}

class _SignaturePadState extends State<SignaturePad> {
  final List<List<Offset>> _strokes = [];
  Size _size = Size.zero;

  Future<void> _save() async {
    if (_strokes.isEmpty) return;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(Offset.zero & _size, Paint()..color = Colors.white);
    _SignaturePainter(_strokes, Colors.black).paint(canvas, _size);
    final image = await recorder.endRecording().toImage(_size.width.ceil(), _size.height.ceil());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes != null) widget.onSave(bytes.buffer.asUint8List());
  }

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          key: const ValueKey('signature-pad'),
          height: 200,
          decoration: BoxDecoration(
            color: kn.bgSurface,
            borderRadius: BorderRadius.circular(KnSize.radiusLg),
            border: Border.all(color: kn.borderStrong),
          ),
          child: LayoutBuilder(
            builder: (context, c) {
              _size = Size(c.maxWidth, c.maxHeight);
              return GestureDetector(
                onPanStart: (d) => setState(() => _strokes.add([d.localPosition])),
                onPanUpdate: (d) => setState(() => _strokes.last.add(d.localPosition)),
                child: CustomPaint(
                  painter: _SignaturePainter(_strokes, kn.textPrimary),
                  child: _strokes.isEmpty
                      ? Center(
                          child: CustomBaseTextWidget(
                            LangKeys.questionSignHere.tr,
                            style: context.knText.body,
                            color: kn.textSecondary,
                          ),
                        )
                      : const SizedBox.expand(),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: KnSize.space12),
        Row(
          children: [
            Expanded(
              child: KnCustomButton(
                text: LangKeys.questionClear.tr,
                variant: KnButtonVariant.secondary,
                onTap: () => setState(_strokes.clear),
              ),
            ),
            const SizedBox(width: KnSize.space8),
            Expanded(
              child: KnCustomButton(
                key: const ValueKey('save-signature'),
                text: LangKeys.questionSaveSignature.tr,
                loading: widget.saving,
                enabled: _strokes.isNotEmpty,
                onTap: _save,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SignaturePainter extends CustomPainter {
  _SignaturePainter(this.strokes, this.color);

  final List<List<Offset>> strokes;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final s in strokes) {
      if (s.length == 1) {
        canvas.drawCircle(s.first, 1.5, paint);
        continue;
      }
      final path = Path()..moveTo(s.first.dx, s.first.dy);
      for (final p in s.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_SignaturePainter old) => true;
}
