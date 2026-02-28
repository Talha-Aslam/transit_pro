import 'dart:ui';
import 'package:flutter/material.dart';

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
    this.boxShadow,
    this.onTap,
    this.clipContent = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null
            ? (backgroundColor ?? Colors.white.withOpacity(0.06))
            : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: borderColor ?? Colors.white.withOpacity(0.10),
          width: borderWidth,
        ),
        boxShadow: boxShadow,
      ),
      child: child,
    );

    Widget blurred = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: content,
      ),
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: blurred);
    }
    return blurred;
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
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 46,
        height: 26,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(13),
          color: value ? activeColor : Colors.white.withOpacity(0.12),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
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
                      color: Colors.black.withOpacity(0.3),
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
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
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

  const GradientButton({
    super.key,
    required this.label,
    required this.gradient,
    this.onTap,
    this.height = 52,
    this.glowColor,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          gradient: isLoading ? null : gradient,
          color: isLoading ? Colors.white.withOpacity(0.1) : null,
          borderRadius: BorderRadius.circular(14),
          boxShadow: (!isLoading && glowColor != null)
              ? [BoxShadow(color: glowColor!.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8))]
              : null,
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(
                  label,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                ),
        ),
      ),
    );
  }
}
