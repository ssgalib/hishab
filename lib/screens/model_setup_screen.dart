import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/expense_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/glass.dart';

/// "One-time setup" — downloads the voice model from Hugging Face.
///
/// Four states from the prototype: idle (terms + download button),
/// downloading (progress + cancel), complete (✓ Model ready), error (retry).
/// Works both as the boot-time gate and pushed from the mic when the user
/// chose "I'll do this later".
class ModelSetupScreen extends StatelessWidget {
  const ModelSetupScreen({super.key, this.popWhenReady = false});

  /// When pushed over the main app, pop back automatically once done.
  final bool popWhenReady;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpenseProvider>();

    // Auto-leave when the download finishes and this screen was pushed.
    if (popWhenReady && provider.modelReady && Navigator.of(context).canPop()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      });
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.9),
            radius: 1.4,
            colors: [Color(0x14A8CC00), AppColors.bg],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 40, 24, 230),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 400),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _IconFrame(),
                        SizedBox(height: 24),
                        Text(
                          'One-time setup',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 22, letterSpacing: -0.22),
                        ),
                        SizedBox(height: 10),
                        Text(
                          'To understand your voice, Hishab needs an AI '
                          'model. It runs entirely on your phone — never '
                          'leaves your device.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.6,
                            color: AppColors.muted,
                          ),
                        ),
                        SizedBox(height: 26),
                        _InfoRow(
                          emoji: '📦',
                          label: '~537 MB',
                          sub: 'Downloaded once, stored on device',
                        ),
                        SizedBox(height: 10),
                        _InfoRow(
                          emoji: '🌐',
                          label: 'Wi-Fi recommended',
                          sub: 'Mobile data will work but check your plan',
                        ),
                        SizedBox(height: 10),
                        _InfoRow(
                          emoji: '🔒',
                          label: 'Stays on this device',
                          sub: 'No account or cloud needed',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _ActionArea(state: provider.modelState),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconFrame extends StatelessWidget {
  const _IconFrame();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GlassContainer(
        radius: 30,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(29),
          child: SizedBox(
            width: 96,
            height: 96,
            child: Image.asset('assets/hishab-icon.png', fit: BoxFit.cover),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.emoji,
    required this.label,
    required this.sub,
  });

  final String emoji;
  final String label;
  final String sub;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      radius: 14,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.accent.withValues(alpha: 0.14),
            ),
            child: Text(emoji,
                style: const TextStyle(fontSize: 18, height: 1)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(
                  sub,
                  style: const TextStyle(
                    fontSize: 11,
                    height: 1.45,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Pinned bottom area that swaps with the model state.
class _ActionArea extends StatelessWidget {
  const _ActionArea({required this.state});

  final ModelState state;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpenseProvider>();
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 14, 20, 30 + MediaQuery.paddingOf(context).bottom),
      child: switch (state) {
        ModelState.downloading => _Downloading(
            received: provider.modelReceived,
            total: provider.modelTotal,
            onCancel: provider.cancelModelDownload,
          ),
        ModelState.ready => const _Complete(),
        ModelState.error => _Error(
            message: provider.modelError,
            onRetry: provider.startModelDownload,
          ),
        _ => _Idle(onDownload: provider.startModelDownload),
      },
    );
  }
}

class _Idle extends StatelessWidget {
  const _Idle({required this.onDownload});

  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PrimaryButton(label: 'Download model — free', onTap: onDownload),
        GestureDetector(
          onTap: () =>
              context.read<ExpenseProvider>().chooseLaterWithoutModel(),
          child: const Padding(
            padding: EdgeInsets.only(top: 12, bottom: 4),
            child: Text(
              "I'll do this later",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.muted),
            ),
          ),
        ),
      ],
    );
  }
}

class _Downloading extends StatelessWidget {
  const _Downloading({
    required this.received,
    required this.total,
    required this.onCancel,
  });

  final int received;
  final int? total;
  final VoidCallback onCancel;

  String _mb(int bytes) => '${(bytes / (1024 * 1024)).round()} MB';

  @override
  Widget build(BuildContext context) {
    final progress =
        total != null && total! > 0 ? (received / total!).clamp(0.0, 1.0) : null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 6,
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppColors.progressTrack,
              color: AppColors.accent,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          total != null
              ? 'Downloading… ${_mb(received)} / ${_mb(total!)}'
              : 'Downloading… ${_mb(received)}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: AppColors.muted),
        ),
        GestureDetector(
          onTap: onCancel,
          child: const Padding(
            padding: EdgeInsets.only(top: 12, bottom: 4),
            child: Text(
              'Cancel',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.muted),
            ),
          ),
        ),
      ],
    );
  }
}

class _Complete extends StatelessWidget {
  const _Complete();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 6,
            child: LinearProgressIndicator(
              value: 1,
              minHeight: 6,
              backgroundColor: AppColors.progressTrack,
              color: AppColors.accent,
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '✓ Model ready',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.accentInk,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Error extends StatelessWidget {
  const _Error({required this.message, required this.onRetry});

  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Download failed. Check your connection and try again.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, height: 1.5, color: AppColors.downloadError),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: onRetry,
          child: Container(
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.downloadError),
            ),
            child: const Text(
              'Retry',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.downloadError,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: AppColors.accent,
          boxShadow: const [
            BoxShadow(
              color: AppColors.accentShadow,
              offset: Offset(0, 4),
              blurRadius: 14,
            ),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.fg,
          ),
        ),
      ),
    );
  }
}
