import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/theme_provider.dart';

/// A glassmorphism card with BackdropFilter blur.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final Color? backgroundColor;
  final Gradient? gradient;
  final Color? borderColor;
  final double borderWidth;
  final double blurSigma;
  final bool enableBlur;
  final List<BoxShadow>? boxShadow;
  final VoidCallback? onTap;
  final bool clipContent;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = 20,
    this.backgroundColor,
    this.gradient,
    this.borderColor,
    this.borderWidth = 1,
    this.blurSigma = 20,
    this.enableBlur = true,
    this.boxShadow,
    this.onTap,
    this.clipContent = false,
  });

  @override
  Widget build(BuildContext context) {
    // Blended, not a hard `isDark` switch — this card is used on nearly
    // every screen, so a snap here would undercut the app-wide smooth
    // theme transition even with every other colour blending correctly.
    // Reads through `ThemeBlendScope` (not `ThemeProvider.instance.blend`
    // directly) so *this* widget is what Flutter marks dirty on each
    // animation tick, rather than relying on some ancestor rebuilding the
    // whole tree around it.
    final blend = ThemeBlendScope.of(context);
    Widget content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null
            ? (backgroundColor ??
                  Color.lerp(
                    Colors.white,
                    Colors.white.withValues(alpha: 0.06),
                    blend,
                  ))
            : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color:
              borderColor ??
              Color.lerp(
                const Color(0xFFE2E8F0),
                Colors.white.withValues(alpha: 0.10),
                blend,
              )!,
          width: borderWidth,
        ),
        boxShadow:
            boxShadow ??
            [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04 * (1 - blend)),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
      ),
      child: child,
    );

    Widget card = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: (enableBlur && !ThemeProvider.instance.isAnimating)
          ? BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
              child: content,
            )
          : content,
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: card);
    }
    return card;
  }
}

/// A simple toggle switch styled to match the app's dark glassmorphism theme.
class AppSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color activeColor;

  const AppSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeColor = const Color(0xFF7C3AED),
  });

  @override
  Widget build(BuildContext context) {
    final blend = ThemeBlendScope.of(context);
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 46,
        height: 26,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(13),
          color: value
              ? activeColor
              : Color.lerp(
                  const Color(0xFFE2E8F0),
                  Colors.white.withValues(alpha: 0.12),
                  blend,
                ),
          border: Border.all(
            color: Color.lerp(
              const Color(0xFFCBD5E1),
              Colors.white.withValues(alpha: 0.1),
              blend,
            )!,
          ),
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              top: 3,
              left: value ? 22 : 3,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Status badge pill widget.
class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final String? dotIndicator;

  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.dotIndicator,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dotIndicator != null) ...[
            Text(dotIndicator!, style: const TextStyle(fontSize: 10)),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// A gradient button used throughout the app.
class GradientButton extends StatelessWidget {
  final String label;
  final Gradient gradient;
  final VoidCallback? onTap;
  final double height;
  final Color? glowColor;
  final bool isLoading;
  final bool isEnabled;

  const GradientButton({
    super.key,
    required this.label,
    required this.gradient,
    this.onTap,
    this.height = 52,
    this.glowColor,
    this.isLoading = false,
    this.isEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final bool disabled = !isEnabled && !isLoading;

    return GestureDetector(
      onTap: isLoading || disabled ? null : onTap,
      child: Opacity(
        // Loading used to swap the gradient for a 10%-white fill, which on
        // the light theme reads as a near-invisible box with a white spinner
        // on a near-white surface — a stuck loading state looked exactly
        // like the button had disappeared. Keeping the gradient (just
        // dimmed) means it's always visibly "this button, doing something"
        // in both themes.
        opacity: disabled ? 0.45 : (isLoading ? 0.7 : 1.0),
        child: Container(
          height: height,
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(14),
            boxShadow: (!isLoading && !disabled && glowColor != null)
                ? [
                    BoxShadow(
                      color: glowColor!.withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
