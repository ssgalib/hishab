import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum MicState { idle, listening, processing }

/// The hero mic FAB: lime circle with pulse rings while listening and a
/// spinner while the on-device model parses.
class MicButton extends StatefulWidget {
  const MicButton({super.key, required this.state, this.onTap});

  final MicState state;
  final VoidCallback? onTap;

  @override
  State<MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<MicButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );

  @override
  void initState() {
    super.initState();
    if (widget.state == MicState.listening) _pulse.repeat();
  }

  @override
  void didUpdateWidget(covariant MicButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state == MicState.listening) {
      if (!_pulse.isAnimating) _pulse.repeat();
    } else {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final listening = widget.state == MicState.listening;
    final processing = widget.state == MicState.processing;
    final child = _MicIcon(state: widget.state);

    return Tooltip(
      message: listening
          ? 'Tap to stop'
          : processing
              ? 'Parsing your expense…'
              : 'Tap to speak',
      child: GestureDetector(
        onTap: processing ? null : widget.onTap,
        child: Opacity(
          opacity: processing ? 0.6 : 1,
          child: SizedBox(
            width: 86,
            height: 86,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                if (listening) ...[
                  _ring(_pulse, 0),
                  _ring(_pulse, 0.5),
                ],
                Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.accent,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accentShadow,
                        offset: Offset(0, 4),
                        blurRadius: 14,
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: child,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _ring(AnimationController controller, double phase) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        var t = controller.value - phase;
        if (t < 0) t += 1;
        return Container(
          width: 72 + 50 * t,
          height: 72 + 50 * t,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.accent.withValues(alpha: 0.55 * (1 - t)),
              width: 2,
            ),
          ),
        );
      },
    );
  }
}

class _MicIcon extends StatelessWidget {
  const _MicIcon({required this.state});

  final MicState state;

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      MicState.idle =>
        const Icon(Icons.mic_none, size: 30, color: AppColors.fg),
      MicState.listening =>
        const Icon(Icons.stop, size: 30, color: AppColors.fg),
      MicState.processing => const SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.6,
            strokeCap: StrokeCap.round,
            color: AppColors.fg,
          ),
        ),
    };
  }
}
