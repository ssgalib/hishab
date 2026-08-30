import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../theme/app_theme.dart';
import '../widgets/glass.dart';

/// First-run onboarding: welcome, privacy promise, an interactive voice
/// demo, the microphone permission ask, and the "ready" hand-off.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onFinish});

  final VoidCallback onFinish;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _stepCount = 5;

  final PageController _page = PageController();
  int _step = 0;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  void _goTo(int index) {
    _page.animateToPage(
      index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  void _finish() {
    HapticFeedback.lightImpact();
    widget.onFinish();
  }

  Future<void> _allowMicrophone() async {
    final status = await Permission.microphone.request();
    if (status.isGranted) HapticFeedback.lightImpact();
    _goTo(_stepCount - 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.9),
            radius: 1.4,
            colors: [Color(0x14A8CC00), AppColors.bg],
          ),
        ),
        child: Stack(
          children: [
            PageView(
              controller: _page,
              onPageChanged: (i) => setState(() => _step = i),
              children: [
                const _WelcomeStep(),
                const _PrivacyStep(),
                const _VoiceStep(),
                const _PermissionStep(),
                _ReadyStep(onStart: _finish),
              ],
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, right: 8),
                  child: TextButton(
                    onPressed: () => _goTo(_stepCount - 1),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.muted,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    child: const Text('Skip', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ),
            ),
            if (_step < _stepCount - 1)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _Foot(
                  step: _step,
                  stepCount: _stepCount,
                  onDotTap: _goTo,
                  onNext: () => _goTo(_step + 1),
                  onAllow: _allowMicrophone,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Glass footer with progress dots and per-step actions.
class _Foot extends StatelessWidget {
  const _Foot({
    required this.step,
    required this.stepCount,
    required this.onDotTap,
    required this.onNext,
    required this.onAllow,
  });

  final int step;
  final int stepCount;
  final ValueChanged<int> onDotTap;
  final VoidCallback onNext;
  final VoidCallback onAllow;

  @override
  Widget build(BuildContext context) {
    final isPermissionStep = step == stepCount - 2;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.navFill,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          padding: EdgeInsets.fromLTRB(
            20,
            14,
            20,
            14 + MediaQuery.paddingOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < stepCount; i++)
                    GestureDetector(
                      onTap: () => onDotTap(i),
                      child: Container(
                        width: i == step ? 24 : 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(5),
                          color: i == step
                              ? AppColors.accent
                              : AppColors.fg.withValues(alpha: 0.16),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              if (isPermissionStep)
                Row(
                  children: [
                    Expanded(
                      child: _GhostButton(label: 'Not now', onTap: onNext),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _PrimaryButton(
                        label: 'Allow microphone',
                        onTap: onAllow,
                      ),
                    ),
                  ],
                )
              else
                _PrimaryButton(
                  label: step == 0 ? 'Get started' : 'Continue',
                  onTap: onNext,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shared step scaffolding: vertically centered column, scrollable when tall.
class _StepScaffold extends StatelessWidget {
  const _StepScaffold({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(26, 56, 26, 150),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight - 56 - 150,
              maxWidth: 400,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 24, letterSpacing: -0.24, height: 1.3),
    );
  }
}

/// Lead paragraph; when [bold] is set it renders: [lead] + **[bold]** + [tail].
class _Lead extends StatelessWidget {
  const _Lead(this.lead, {this.bold, this.tail});

  final String lead;
  final String? bold;
  final String? tail;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: 13, height: 1.6, color: AppColors.muted);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: lead),
          if (bold != null)
            TextSpan(
              text: bold,
              style: const TextStyle(color: AppColors.fg),
            ),
          if (tail != null) TextSpan(text: tail),
        ],
      ),
      textAlign: TextAlign.center,
      style: style,
    );
  }
}

class _IconCircle extends StatelessWidget {
  const _IconCircle(this.icon, {this.iconSize = 42});

  final IconData icon;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 96,
        height: 96,
        margin: const EdgeInsets.only(bottom: 26),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.accent.withValues(alpha: 0.14),
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(icon, size: iconSize, color: AppColors.accentInk),
      ),
    );
  }
}

class _IconFrame extends StatelessWidget {
  const _IconFrame({this.size = 112, this.radius = 30, this.margin = true});

  final double size;
  final double radius;
  final bool margin;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GlassContainer(
        radius: radius,
        margin: margin ? const EdgeInsets.only(bottom: 26) : EdgeInsets.zero,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius - 1),
          child: SizedBox(
            width: size,
            height: size,
            child: Image.asset('assets/hishab-icon.png', fit: BoxFit.cover),
          ),
        ),
      ),
    );
  }
}

// ─── Steps ────────────────────────────────────────────────────────────────

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep();

  @override
  Widget build(BuildContext context) {
    return const _StepScaffold(
      children: [
        _IconFrame(),
        _Title('Meet Hishab'),
        SizedBox(height: 12),
        _Lead(
          "A voice-first expense tracker for everyday life. Say it, and it's "
          'recorded — in taka, on this phone.',
        ),
      ],
    );
  }
}

class _PrivacyStep extends StatelessWidget {
  const _PrivacyStep();

  @override
  Widget build(BuildContext context) {
    return const _StepScaffold(
      children: [
        _IconCircle(Icons.lock_outline),
        _Title('Your money stays on your phone.'),
        SizedBox(height: 12),
      _Lead(
        'No account. No cloud. Hishab runs fully offline — your expenses '
        'never leave this device.',
      ),
        SizedBox(height: 26),
        _PrivacyRow(
          icon: Icons.mic_none,
          tag: 'On-device AI',
          body: 'Your voice is parsed right here on the phone.',
        ),
        SizedBox(height: 10),
        _PrivacyRow(
          icon: Icons.home_outlined,
          tag: 'No account',
          body: 'Nothing to sign up for, nothing to sync.',
        ),
        SizedBox(height: 10),
        _PrivacyRow(
          icon: Icons.download,
          tag: 'No uploads',
          body: 'Data never leaves this device.',
        ),
      ],
    );
  }
}

class _PrivacyRow extends StatelessWidget {
  const _PrivacyRow({
    required this.icon,
    required this.tag,
    required this.body,
  });

  final IconData icon;
  final String tag;
  final String body;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      radius: 12,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.accent.withValues(alpha: 0.14),
            ),
            child: Icon(icon, size: 19, color: AppColors.accentInk),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tag.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    letterSpacing: 1,
                    color: AppColors.accentInk,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
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

/// Step 3 — the tappable mic demo that plays the full voice flow.
class _VoiceStep extends StatefulWidget {
  const _VoiceStep();

  @override
  State<_VoiceStep> createState() => _VoiceStepState();
}

enum _DemoPhase { idle, listening, processing, done }

class _VoiceStepState extends State<_VoiceStep> {
  static const _words = ['bought', 'three', 'eggs', 'for', 'fifty', 'taka'];

  _DemoPhase _phase = _DemoPhase.idle;
  int _wordCount = 0;
  Timer? _streamTimer;
  Timer? _processTimer;

  @override
  void dispose() {
    _streamTimer?.cancel();
    _processTimer?.cancel();
    super.dispose();
  }

  void _startListening() {
    _streamTimer?.cancel();
    _processTimer?.cancel();
    setState(() {
      _phase = _DemoPhase.listening;
      _wordCount = 0;
    });
    _streamTimer = Timer.periodic(const Duration(milliseconds: 260), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_wordCount < _words.length) {
        setState(() => _wordCount++);
      } else {
        t.cancel();
        _goProcessing();
      }
    });
  }

  void _stopAndParse() {
    _streamTimer?.cancel();
    _goProcessing();
  }

  void _goProcessing() {
    setState(() => _phase = _DemoPhase.processing);
    _processTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _phase = _DemoPhase.done);
    });
  }

  void _reset() {
    _streamTimer?.cancel();
    _processTimer?.cancel();
    setState(() {
      _phase = _DemoPhase.idle;
      _wordCount = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final words = _words.take(_wordCount).join(' ');
    final label = switch (_phase) {
      _DemoPhase.idle => 'Tap to try it',
      _DemoPhase.listening => 'Listening — tap to stop',
      _DemoPhase.processing => 'Parsing your expense…',
      _DemoPhase.done => 'Saved — 3 eggs · ৳50',
    };

    return _StepScaffold(
      children: [
        const _IconCircle(Icons.mic_none),
        const _Title("Say it like you'd tell a friend."),
        const SizedBox(height: 12),
        const _Lead(
          'Tap the mic and say ',
          bold: '"3 eggs for 50 taka"',
          tail: " — we'll figure out the rest.",
        ),
        const SizedBox(height: 26),
        GlassContainer(
          radius: 18,
          blur: true,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
          child: Column(
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: switch (_phase) {
                      _DemoPhase.idle => _startListening,
                      _DemoPhase.listening => _stopAndParse,
                      _ => null,
                    },
                    child: _MiniMic(phase: _phase),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: SizedBox(
                      height: 64,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 9,
                              letterSpacing: 1.08,
                              color: AppColors.muted,
                            ),
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            height: 18,
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    _phase == _DemoPhase.done ? '' : words,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.fg,
                                    ),
                                  ),
                                ),
                                if (_phase == _DemoPhase.idle ||
                                    _phase == _DemoPhase.listening)
                                  const Blink(
                                    duration: Duration(milliseconds: 800),
                                    child: SizedBox(
                                      width: 2,
                                      height: 13,
                                      child: ColoredBox(
                                        color: AppColors.accent,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              _ParsedRow(visible: _phase == _DemoPhase.done),
              if (_phase == _DemoPhase.done) ...[
                const SizedBox(height: 14),
                Center(
                  child: GestureDetector(
                    onTap: _reset,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: AppColors.fg.withValues(alpha: 0.25),
                        ),
                      ),
                      child: const Text(
                        'Play again',
                        style: TextStyle(fontSize: 11, color: AppColors.muted),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        const _ExampleChip('Rickshaw to the bazar, 60 taka'),
        const SizedBox(height: 8),
        const _ExampleChip('Mobile recharge, 100 taka'),
      ],
    );
  }
}

/// Small 64px version of the mic FAB for the demo card.
class _MiniMic extends StatelessWidget {
  const _MiniMic({required this.phase});

  final _DemoPhase phase;

  @override
  Widget build(BuildContext context) {
    final listening = phase == _DemoPhase.listening;
    final processing = phase == _DemoPhase.processing;
    return Opacity(
      opacity: processing ? 0.6 : 1,
      child: SizedBox(
        width: 64,
        height: 64,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            if (listening) ...[
              const _PulseRing(offset: 0),
              const _PulseRing(offset: 0.5),
            ],
            Container(
              width: 64,
              height: 64,
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
              child: Center(
                child: switch (phase) {
                  _DemoPhase.idle => const Icon(
                    Icons.mic_none,
                    size: 26,
                    color: AppColors.fg,
                  ),
                  _DemoPhase.listening => const Icon(
                    Icons.stop,
                    size: 26,
                    color: AppColors.fg,
                  ),
                  _DemoPhase.processing => const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.6,
                      strokeCap: StrokeCap.round,
                      color: AppColors.fg,
                    ),
                  ),
                  _DemoPhase.done => const Icon(
                    Icons.check,
                    size: 26,
                    color: AppColors.fg,
                  ),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PulseRing extends StatefulWidget {
  const _PulseRing({required this.offset});

  final double offset;

  @override
  State<_PulseRing> createState() => _PulseRingState();
}

class _PulseRingState extends State<_PulseRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
    value: widget.offset,
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return Container(
          width: 64 + 38 * t,
          height: 64 + 38 * t,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.accent.withValues(alpha: 0.5 * (1 - t)),
              width: 2,
            ),
          ),
        );
      },
    );
  }
}

class _ParsedRow extends StatelessWidget {
  const _ParsedRow({required this.visible});

  final bool visible;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: const Duration(milliseconds: 300),
      child: AnimatedSlide(
        offset: visible ? Offset.zero : const Offset(0, 0.08),
        duration: const Duration(milliseconds: 300),
        child: GlassContainer(
          radius: 12,
          margin: const EdgeInsets.only(top: 16),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: const Row(
            children: [
              _ParsedAvatar(),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '3 eggs',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Food · just now',
                      style: TextStyle(fontSize: 10, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              Text(
                '৳50',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.accentInk,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ParsedAvatar extends StatelessWidget {
  const _ParsedAvatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: CategoryPalette.food.withValues(alpha: 0.10),
      ),
      child: const Icon(
        Icons.restaurant,
        size: 19,
        color: CategoryPalette.foodInk,
      ),
    );
  }
}

class _ExampleChip extends StatelessWidget {
  const _ExampleChip(this.phrase);

  final String phrase;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      radius: 12,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Text.rich(
        TextSpan(
          children: [
            const TextSpan(text: 'Try: '),
            TextSpan(
              text: '"$phrase"',
              style: const TextStyle(color: AppColors.fg),
            ),
          ],
        ),
        style: const TextStyle(fontSize: 12, color: AppColors.muted),
      ),
    );
  }
}

class _PermissionStep extends StatelessWidget {
  const _PermissionStep();

  @override
  Widget build(BuildContext context) {
    return _StepScaffold(
      children: [
        GlassContainer(
          radius: 18,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const _IconFrame(size: 52, radius: 15, margin: false),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Use your microphone?',
                          style: TextStyle(fontSize: 15),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Hishab',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: 'To record expenses by voice. Your speech '),
                    TextSpan(
                      text: 'is processed on this device',
                      style: TextStyle(color: AppColors.fg),
                    ),
                    TextSpan(text: ' — nothing is recorded or uploaded.'),
                  ],
                ),
                style: TextStyle(
                  fontSize: 12,
                  height: 1.6,
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReadyStep extends StatelessWidget {
  const _ReadyStep({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return _StepScaffold(
      children: [
        const _IconCircle(Icons.check, iconSize: 46),
        const _Title("You're all set."),
        const SizedBox(height: 12),
        const _Lead(
          "Tap the mic and say your first expense — it'll be saved on this "
          'phone only.',
        ),
        const SizedBox(height: 26),
        _PrimaryButton(label: 'Start tracking', onTap: onStart),
      ],
    );
  }
}

// ─── Buttons ──────────────────────────────────────────────────────────────

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
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

class _GhostButton extends StatelessWidget {
  const _GhostButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

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
        child: Text(
          label,
          style: const TextStyle(fontSize: 14, color: AppColors.fg),
        ),
      ),
    );
  }
}
