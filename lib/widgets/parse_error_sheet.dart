import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'glass.dart';

enum ParseErrorAction { retry, manual }

/// Shown when the on-device model couldn't turn the spoken sentence into an
/// expense: offers "Try again" (re-listen) or "Enter manually".
Future<ParseErrorAction?> showParseErrorSheet(
  BuildContext context, {
  required String heard,
}) {
  return showGlassSheet<ParseErrorAction>(
    context: context,
    builder: (_) => _ParseErrorSheet(heard: heard),
  );
}

class _ParseErrorSheet extends StatelessWidget {
  const _ParseErrorSheet({required this.heard});

  final String heard;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SheetHandle(),
        const Text("Couldn't understand that",
            style: TextStyle(fontSize: 19)),
        const SizedBox(height: 4),
        const Text(
          "Tell us again, or type it in — it's quick.",
          style: TextStyle(fontSize: 12, color: AppColors.muted),
        ),
        const SizedBox(height: 14),
        GlassContainer(
          radius: 14,
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 3),
                child:
                    Icon(Icons.mic_none, size: 15, color: AppColors.accentInk),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'WE HEARD',
                      style: TextStyle(
                          fontSize: 9, letterSpacing: 0.9, color: AppColors.muted),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '“$heard”',
                      style: const TextStyle(fontSize: 13, height: 1.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _GhostButton(
                label: 'Try again',
                icon: Icons.mic_none,
                onTap: () => Navigator.of(context).pop(ParseErrorAction.retry),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _GhostButton(
                label: 'Enter manually',
                onTap: () =>
                    Navigator.of(context).pop(ParseErrorAction.manual),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _GhostButton extends StatelessWidget {
  const _GhostButton({required this.label, required this.onTap, this.icon});

  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.fg.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: AppColors.fg),
              const SizedBox(width: 8),
            ],
            Text(label, style: const TextStyle(fontSize: 14, color: AppColors.fg)),
          ],
        ),
      ),
    );
  }
}
