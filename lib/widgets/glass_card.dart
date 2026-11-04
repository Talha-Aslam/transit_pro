import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';

/// An opaque surface card.
///
/// Kept its name and its whole API — it is used on 150-odd call sites — but
/// it no longer blurs anything. A `BackdropFilter` behind every card meant
/// each one sampled and blurred the frame beneath it on every repaint, and
/// the pale fill it carried only read as a surface over the old purple
/// gradient; over a map, a photo header or another card it was just a wash.
/// Now: a real fill, one hairline border, and a shadow in light mode only.
///
/// [enableBlur] and [blurSigma] are accepted and ignored, so the call sites
/// that pass them keep compiling.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final Color? backgroundColor;
  final Gradient? gradient;
  final Color? borderColor;
  final double borderWidth;

  /// Marks the card as belonging to one status or role: a 3px bar down the
  /// leading edge, plus the standard [AppTheme.accentWash] over the surface
  /// and a border in the same colour.
  ///
  /// This is what separates a card that is *about* something — a live route,
  /// an alert, a payment due — from the plain surfaces around it. Tinting
  /// the whole card instead, which is what these call sites used to do, says
  /// the same thing much more loudly and stops reading as a card at all once
  /// several of them stack up on one screen.
  final Color? accent;

  /// Ignored. See the class comment.
  final double blurSigma;

  /// Ignored. See the class comment.
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
    this.accent,
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
    final radius = BorderRadius.circular(borderRadius);

    // A [gradient] used to BE the card: 27 call sites pass a two-stop accent
    // wash at 15%/5% alpha, which over the old purple backdrop looked like a
    // tinted pane of glass. On a flat ground the same wash is simply a
    // washed-out card. So the gradient is now painted ON the solid surface
    // rather than instead of it — the card stays opaque and the accent reads
    // as a tint, which is what those call sites wanted all along.
    final wash =
        gradient ?? (accent == null ? null : AppTheme.accentWash(accent!));

    Widget inner = Padding(padding: padding ?? EdgeInsets.zero, child: child);
    if (wash != null) {
      inner = DecoratedBox(
        decoration: BoxDecoration(gradient: wash, borderRadius: radius),
        child: inner,
      );
    }
    if (accent != null) {
      // The content is the Stack's one NON-positioned child, so it is what
      // the Stack takes its size from. With everything positioned — which is
      // what `Positioned.fill` makes it — the Stack has nothing to measure
      // and collapses to the smallest size allowed, which took every card on
      // the parent and student dashboards down to a hairline.
      inner = Stack(
        children: [
          inner,
          PositionedDirectional(
            start: 0,
            top: 0,
            bottom: 0,
            child: Container(width: 3, color: accent),
          ),
        ],
      );
    }

    Widget content = Container(
      decoration: BoxDecoration(
        color:
            backgroundColor ??
            Color.lerp(
              AppTheme.lightSurfaceCard,
              AppTheme.darkSurfaceCard,
              blend,
            ),
        borderRadius: radius,
        border: Border.all(
          color:
              borderColor ??
              (accent != null
                  ? accent!.withValues(alpha: 0.22)
                  : Color.lerp(
                      AppTheme.lightSurfaceBorder,
                      AppTheme.darkSurfaceBorder,
                      blend,
                    )!),
          width: borderWidth,
        ),
        boxShadow: boxShadow ?? AppTheme.cardShadowFor(blend),
      ),
      child: inner,
    );

    Widget card = ClipRRect(borderRadius: radius, child: content);

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: card);
    }
    return card;
  }
}

/// A simple toggle switch styled to match the app's surface palette.
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
                  AppTheme.lightSurfaceRaised,
                  AppTheme.darkSurfaceRaised,
                  blend,
                ),
          border: Border.all(
            color: Color.lerp(
              AppTheme.lightInputBorder,
              AppTheme.darkInputBorder,
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
