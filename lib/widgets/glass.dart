import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Frosted-glass surface from the prototype: cream fill at ~55% alpha,
/// bright white rim, soft warm shadow and a hairline top highlight.
///
/// [blur] adds a real backdrop blur — only worth it for floating elements
/// (nav bar, caption, sheets); over the flat gradient background it is
/// visually identical, so tiles/cards ship without it.
class GlassContainer extends StatelessWidget {
  const GlassContainer({
    super.key,
    required this.child,
    this.radius = 14,
    this.blur = false,
    this.fill = AppColors.glassFill,
    this.borderColor = AppColors.border,
    this.borderWidth = 1,
    this.shadowColor = AppColors.warmShadow,
    this.padding,
    this.margin,
    this.highlight = true,
  });

  final Widget child;
  final double radius;
  final bool blur;
  final Color fill;
  final Color borderColor;
  final double borderWidth;
  final Color? shadowColor;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    Widget content = Padding(
      padding: margin ?? EdgeInsets.zero,
      child: Container(
      padding: padding,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: borderRadius,
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: [
          if (shadowColor != null)
            BoxShadow(
              color: shadowColor!,
              offset: const Offset(0, 4),
              blurRadius: 24,
            ),
        ],
      ),
      foregroundDecoration: highlight
          ? BoxDecoration(
              borderRadius: borderRadius,
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xD9FFFFFF), Color(0x00FFFFFF)],
                stops: [0, 0.06],
              ),
            )
          : null,
      child: child,
      ),
    );

    if (blur) {
      content = ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: content,
        ),
      );
    }
    return content;
  }
}

/// 44x44 rounded icon button used in the History app bar.
class GlassIconBtn extends StatelessWidget {
  const GlassIconBtn({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color = AppColors.muted,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, size: 21, color: color),
        ),
      ),
    );
  }
}

/// Glass pill segmented control (Day/Month/Year on Home).
class GlassSegmented<T> extends StatelessWidget {
  const GlassSegmented({
    super.key,
    required this.segments,
    required this.selected,
    required this.onSelected,
  });

  final Map<T, String> segments;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      radius: 14,
      padding: const EdgeInsets.all(3),
      child: Row(
        children: [
          for (final entry in segments.entries)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onSelected(entry.key),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 40),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: entry.key == selected
                        ? const Color(0xCCFFFFFF)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                    boxShadow: entry.key == selected
                        ? const [
                            BoxShadow(
                              color: Color(0x1F1A1612),
                              offset: Offset(0, 1),
                              blurRadius: 3,
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    entry.value,
                    style: TextStyle(
                      fontSize: 12,
                      letterSpacing: 0.48,
                      color: entry.key == selected
                          ? AppColors.accentInk
                          : AppColors.muted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Looping opacity pulse (prototype's `blink` keyframes).
class Blink extends StatefulWidget {
  const Blink({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1000),
    this.minOpacity = 0.3,
  });

  final Widget child;
  final Duration duration;
  final double minOpacity;

  @override
  State<Blink> createState() => _BlinkState();
}

class _BlinkState extends State<Blink>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
    lowerBound: widget.minOpacity,
    upperBound: 1,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      FadeTransition(opacity: _controller, child: widget.child);
}

/// Shows a prototype-styled bottom sheet: transparent modal, blurred cream
/// surface with a 26px top radius and drag handle baked into [builder].
Future<T?> showGlassSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isDismissible = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    isDismissible: isDismissible,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.barrier,
    elevation: 0,
    builder: (context) {
      Widget sheet = ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.sheetFill,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 26),
            child: builder(context),
          ),
        ),
      );
      sheet = Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: sheet,
      );
      return sheet;
    },
  );
}

/// Drag handle shown at the top of every glass sheet.
class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});

  @override
  Widget build(BuildContext context) => Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(2),
          color: AppColors.fg.withValues(alpha: 0.18),
        ),
      );
}
