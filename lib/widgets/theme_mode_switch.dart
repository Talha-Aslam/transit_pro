import 'package:flutter/material.dart';
import '../theme/theme_provider.dart';

/// A "Day / Night" pill switch — a glass track, a sun/moon knob that slides
/// between its ends, and a coloured glow (amber for day, indigo for night)
/// that travels with it. Replaces the plain icon button that used to sit in
/// the role-selection screen's corner.
///
/// Reads [ThemeBlendScope] (not `ThemeProvider.instance.blend` directly) so
/// this widget — not some ancestor — is what Flutter marks dirty on each
/// animation tick, matching every other theme-aware widget added for the
/// app's smooth light/dark transition.
class ThemeModeSwitch extends StatelessWidget {
  final double width;
  final double height;

  const ThemeModeSwitch({super.key, this.width = 102, this.height = 44});

  static const _dayColor = Color(0xFFFBBF24);
  static const _dayColorDeep = Color(0xFFF97316);
  static const _nightColor = Color(0xFF60A5FA);
  static const _nightColorDeep = Color(0xFF4338CA);

  @override
  Widget build(BuildContext context) {
    final blend = ThemeBlendScope.of(context); // 0 = day, 1 = night
    final radius = height / 2;
    final knobSize = height - 8;
    final travel = width - knobSize - 8;
    final knobLeft = 4 + blend * travel;

    final glowColor = Color.lerp(_dayColor, _nightColor, blend)!;

    return GestureDetector(
      onTap: () => ThemeProvider.instance.toggle(),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Colors.white.withValues(alpha: 0.22),
              Colors.white.withValues(alpha: 0.08),
            ],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
          boxShadow: [
            BoxShadow(
              color: glowColor.withValues(alpha: 0.35),
              blurRadius: 16,
              spreadRadius: -2,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // Soft coloured glow that travels with the knob.
              Positioned(
                left: knobLeft - knobSize * 0.4,
                child: IgnorePointer(
                  child: Container(
                    width: knobSize * 1.8,
                    height: knobSize * 1.8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          glowColor.withValues(alpha: 0.55),
                          glowColor.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Label — a plain linear crossfade across the whole range
              // (not two separately-thresholded ranges) so neither label
              // pops in/out partway through the slide; it just fades as
              // steadily as the knob moves.
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: knobSize * 0.6),
                  child: Stack(
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: Opacity(
                          opacity: 1 - blend,
                          child: const Text(
                            'Day',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Opacity(
                          opacity: blend,
                          child: const Text(
                            'Night',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // The sliding knob itself.
              Positioned(
                left: knobLeft,
                child: Container(
                  width: knobSize,
                  height: knobSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      center: const Alignment(-0.3, -0.3),
                      colors: [
                        Color.lerp(_dayColor, _nightColor, blend)!,
                        Color.lerp(_dayColorDeep, _nightColorDeep, blend)!,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: glowColor.withValues(alpha: 0.6),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Center(
                    // A rotating crossfade rather than a hard swap at
                    // blend == 0.5 — that instant cut is what made the
                    // knob's motion read as choppy even though its
                    // position itself was already animating smoothly.
                    child: Transform.rotate(
                      angle: blend * 3.14159,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Opacity(
                            opacity: (1 - blend * 2).clamp(0.0, 1.0),
                            child: Icon(
                              Icons.wb_sunny_rounded,
                              color: Colors.white,
                              size: knobSize * 0.55,
                            ),
                          ),
                          Opacity(
                            opacity: ((blend - 0.5) * 2).clamp(0.0, 1.0),
                            child: Transform.rotate(
                              angle: -blend * 3.14159,
                              child: Icon(
                                Icons.nightlight_round,
                                color: Colors.white,
                                size: knobSize * 0.55,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
