import 'dart:math';

import 'package:flutter/material.dart';

/// Waveform bars for a voice note (M27–M29).
///
/// With [levels] it draws the live loudness while recording; otherwise a fixed shape made from [seed]
/// (the server does not send the real waveform). Bars before [progress] use [playedColor].
class VoiceWave extends StatelessWidget {
  const VoiceWave({
    super.key,
    this.seed = '',
    this.levels,
    this.progress = 0,
    required this.color,
    required this.playedColor,
    this.height = 32,
    this.barWidth = 3,
    this.gap = 3,
  });

  final String seed;
  final List<double>? levels;
  final double progress;
  final Color color;
  final Color playedColor;
  final double height;
  final double barWidth;
  final double gap;

  static List<double> shape(String seed, int count) {
    final r = Random(seed.hashCode);
    return [for (var i = 0; i < count; i++) 0.25 + r.nextDouble() * 0.75];
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, box) {
          final count = max(1, ((box.maxWidth + gap) / (barWidth + gap)).floor());
          final live = levels;
          final values = live == null
              ? shape(seed, count)
              : [
                  ...List.filled(max(0, count - live.length), 0.0),
                  ...live.skip(max(0, live.length - count)),
                ];
          final played = (progress.clamp(0.0, 1.0) * count).round();
          return SizedBox(
            height: height,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var i = 0; i < values.length; i++)
                  Container(
                    width: barWidth,
                    height: max(4, height * values[i]),
                    decoration: BoxDecoration(
                      color: i < played ? playedColor : color,
                      borderRadius: BorderRadius.circular(barWidth / 2),
                    ),
                  ),
              ],
            ),
          );
        },
      );
}
