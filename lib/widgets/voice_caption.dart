import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'glass.dart';

/// Floating voice caption shown above the mic while listening/processing:
/// a blinking status dot, an uppercase label, the recognized words and a
/// terminal-style cursor.
class VoiceCaption extends StatelessWidget {
  const VoiceCaption({
    super.key,
    required this.label,
    required this.text,
    required this.processing,
  });

  final String label;
  final String text;
  final bool processing;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      radius: 18,
      blur: true,
      fill: AppColors.glassFillStrong,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _dot(),
              const SizedBox(width: 7),
              Text(
                label.toUpperCase(),
                style: const TextStyle(
                  fontSize: 10,
                  letterSpacing: 1,
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 24),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: text),
                  if (!processing)
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Blink(
                        duration: const Duration(milliseconds: 800),
                        child: Container(
                          width: 2,
                          height: 16,
                          margin: const EdgeInsets.only(left: 2),
                          color: AppColors.accent,
                        ),
                      ),
                    ),
                ],
              ),
              style: const TextStyle(fontSize: 15, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dot() {
    final dot = Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.accent,
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.7),
            blurRadius: 10,
          ),
        ],
      ),
    );
    return processing ? dot : Blink(child: dot);
  }
}
