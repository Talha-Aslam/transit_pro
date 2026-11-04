import 'package:flutter/material.dart';

import '../app/language_provider.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';

/// The photographic banner every role's dashboard opens on.
///
/// Two assets, one per theme: a morning skyline for light, a lit highway at
/// night for dark. Both are cross-faded by the same `ThemeBlendScope` value
/// the rest of the palette animates on, so switching theme slides the picture
/// over instead of cutting to it.
///
/// Three things make the image read as part of the page rather than a tile
/// pasted at the top:
///
///  * it bleeds past the status bar to the very top edge;
///  * its lower third dissolves into the screen colour, so there is no hard
///    horizontal line where the photograph stops;
///  * a horizontal scrim darkens (or lightens) the side the text sits on,
///    which is also the side both renders were composed to leave empty.
///
/// Height is a fraction of the screen rather than a constant: on a short
/// phone a fixed banner eats the first card, and on a tall one it leaves the
/// greeting marooned.
class DashboardHeader extends StatelessWidget {
  /// "Good Morning" / "Good Afternoon" / "Good Evening", already localised.
  final String greeting;

  /// Whatever goes under the greeting — usually the person's name and one
  /// line about them. Laid out by the caller so each role can say its own
  /// thing (a driver's vehicle, a parent's children).
  final Widget body;

  /// Pinned to the right of the greeting line, vertically centred against
  /// the text block. The notification bell on every dashboard today.
  final Widget? trailing;

  /// The line under [body]. Defaults to the app's own one-liner; pass an
  /// empty string to drop it on a screen that has nothing to add.
  final String? tagline;

  const DashboardHeader({
    super.key,
    required this.greeting,
    required this.body,
    this.trailing,
    this.tagline,
  });

  // JPEG, not PNG: these are photographs, and at 1440x726 the lossless
  // version cost 1.7MB apiece in the APK against 86KB here.
  static const _light = 'assets/images/dashboard/header_light.jpg';
  static const _dark = 'assets/images/dashboard/header_dark.jpg';

  @override
  Widget build(BuildContext context) {
    final blend = ThemeBlendScope.of(context);
    final screenBg = Color.lerp(
      AppTheme.lightSurfaceBg,
      AppTheme.darkSurfaceBg,
      blend,
    )!;

    // One colour on every dashboard rather than the role accent — see
    // `AppTheme.greetingDark`.
    final greetingColor = Color.lerp(
      AppTheme.greetingLight,
      AppTheme.greetingDark,
      blend,
    )!;

    final taglineText = tagline ?? AppStrings.t('dashboard_tagline');

    final media = MediaQuery.of(context);
    // Status-bar height is included, since the image runs underneath it.
    final height =
        (media.size.height * 0.21).clamp(150.0, 184.0) + media.padding.top;

    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Both renders stay mounted and cross-fade. Decoding one and
          // throwing away the other on every theme toggle showed a blank
          // banner for a frame or two on a mid-range phone.
          Opacity(
            opacity: 1 - blend,
            child: Image.asset(
              _light,
              fit: BoxFit.cover,
              alignment: Alignment.bottomCenter,
            ),
          ),
          Opacity(
            opacity: blend,
            child: Image.asset(
              _dark,
              fit: BoxFit.cover,
              alignment: Alignment.bottomCenter,
            ),
          ),

          // Legibility behind the text, on the side both images leave open.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: const Alignment(-1, -0.6),
                end: const Alignment(1, 0.6),
                colors: [
                  screenBg.withValues(alpha: 0.82),
                  screenBg.withValues(alpha: 0.46),
                  screenBg.withValues(alpha: 0.0),
                ],
                stops: const [0.0, 0.38, 0.72],
              ),
            ),
          ),

          // The dissolve. Nothing below this point is a visible edge.
          //
          // `Positioned`, not `Align` + `SizedBox(height:)`: a `DecoratedBox`
          // has no intrinsic size, so inside a loosely-constrained `SizedBox`
          // it collapsed to zero width and painted nothing at all. The left
          // of the banner still looked faded because the scrim above already
          // takes that side almost to the page colour — on the bright side,
          // where the bus and the street lamps are, the photograph ran at
          // full strength straight into a hard horizontal edge.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: height * 0.52,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      screenBg.withValues(alpha: 0.0),
                      screenBg.withValues(alpha: 0.42),
                      screenBg.withValues(alpha: 0.86),
                      screenBg,
                    ],
                    stops: const [0.0, 0.38, 0.74, 0.96],
                  ),
                ),
              ),
            ),
          ),

          Positioned(
            left: 20,
            right: 20,
            top: media.padding.top + 14,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('👋', style: TextStyle(fontSize: 16)),
                          const SizedBox(width: 7),
                          Flexible(
                            child: Text(
                              greeting,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: greetingColor,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      body,
                      if (taglineText.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          taglineText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.textSecondary,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 12), trailing!],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
