
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transit_pro/theme/app_theme.dart';
import 'package:transit_pro/widgets/glass_card.dart';

/// `GlassCard` is on ~150 call sites, so a layout or paint regression here
/// shows up on every screen at once — which is exactly what happened when
/// the accent rail first went in and took every card on the parent and
/// student dashboards down to a hairline.
void main() {
  Widget host(Widget child) => MaterialApp(
        home: Scaffold(
          body: Center(child: SizedBox(width: 300, child: child)),
        ),
      );

  BoxDecoration decorationOf(WidgetTester tester) {
    final container = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(GlassCard),
            matching: find.byType(Container),
          )
          .first,
    );
    return container.decoration! as BoxDecoration;
  }

  testWidgets('sizes itself to its content', (tester) async {
    await tester.pumpWidget(
      host(
        const GlassCard(
          padding: EdgeInsets.all(16),
          child: SizedBox(height: 80, width: 200),
        ),
      ),
    );
    // 80 content + 32 padding + the 1px border on each edge.
    expect(tester.getSize(find.byType(GlassCard)).height, 80 + 32 + 2);
  });

  testWidgets('an accent card keeps its content size', (tester) async {
    // The regression: with every child of the rail Stack positioned, the
    // Stack had nothing to measure and collapsed, so the card became a
    // hairline and the dashboards rendered blank.
    await tester.pumpWidget(
      host(
        const GlassCard(
          accent: Color(0xFF7C3AED),
          padding: EdgeInsets.all(16),
          child: SizedBox(height: 80, width: 200),
        ),
      ),
    );
    // 80 content + 32 padding + the 1px border on each edge.
    expect(tester.getSize(find.byType(GlassCard)).height, 80 + 32 + 2);
  });

  testWidgets('an accent card draws a 3px rail down its leading edge',
      (tester) async {
    const accent = Color(0xFF7C3AED);
    await tester.pumpWidget(
      host(
        const GlassCard(
          accent: accent,
          padding: EdgeInsets.all(16),
          child: SizedBox(height: 80, width: 200),
        ),
      ),
    );

    final rail = find.byWidgetPredicate(
      (w) => w is Container && w.color == accent,
    );
    expect(rail, findsOneWidget);

    // The rail sits inside the 1px border, flush with the leading edge and
    // running the full height between the top and bottom borders.
    const borderWidth = 1.0;
    final cardRect = tester.getRect(find.byType(GlassCard));
    final railRect = tester.getRect(rail);
    expect(railRect.width, 3);
    expect(railRect.left, cardRect.left + borderWidth);
    expect(railRect.height, cardRect.height - borderWidth * 2);
  });

  testWidgets('is opaque — no blur filter anywhere in the tree',
      (tester) async {
    // The whole point of the redesign: a card is a surface, not a pane of
    // glass over whatever happens to be behind it.
    await tester.pumpWidget(
      host(const GlassCard(child: SizedBox(height: 40))),
    );
    expect(find.byType(BackdropFilter), findsNothing);

    final decoration = decorationOf(tester);
    expect(decoration.color, isNotNull);
    expect(decoration.color!.a, 1.0);
  });

  testWidgets('enableBlur is accepted and ignored', (tester) async {
    // Kept only so the call sites that still pass it keep compiling.
    await tester.pumpWidget(
      host(const GlassCard(enableBlur: true, child: SizedBox(height: 40))),
    );
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('an accent card borders in its own colour', (tester) async {
    const accent = Color(0xFF0EA5E9);
    await tester.pumpWidget(
      host(const GlassCard(accent: accent, child: SizedBox(height: 40))),
    );
    final border = decorationOf(tester).border! as Border;
    expect(border.top.color.r, accent.r);
    expect(border.top.color.g, accent.g);
    expect(border.top.color.b, accent.b);
  });

  group('AppTheme.cardShadowFor', () {
    test('lifts the card in light mode', () {
      expect(AppTheme.cardShadowFor(0), isNotEmpty);
    });

    test('is removed entirely in dark mode', () {
      // On #121417 a shadow muddies the edge instead of lifting it; the step
      // up to #1C1F24 is what separates the card there.
      expect(AppTheme.cardShadowFor(1), isEmpty);
    });

    test('fades out as the theme blends toward dark', () {
      final light = AppTheme.cardShadowFor(0).first.color.a;
      final mid = AppTheme.cardShadowFor(0.5).first.color.a;
      expect(mid, lessThan(light));
    });
  });

  group('surface tokens', () {
    test('cards are distinguishable from the ground in both themes', () {
      expect(AppTheme.lightSurfaceCard, isNot(AppTheme.lightSurfaceBg));
      expect(AppTheme.darkSurfaceCard, isNot(AppTheme.darkSurfaceBg));
    });

    test('the dark ramp climbs: ground < card < raised', () {
      double lum(Color c) => c.computeLuminance();
      expect(lum(AppTheme.darkSurfaceBg), lessThan(lum(AppTheme.darkSurfaceCard)));
      expect(
        lum(AppTheme.darkSurfaceCard),
        lessThan(lum(AppTheme.darkSurfaceRaised)),
      );
    });

    test('every surface is fully opaque', () {
      for (final c in [
        AppTheme.lightSurfaceBg,
        AppTheme.lightSurfaceCard,
        AppTheme.lightSurfaceRaised,
        AppTheme.darkSurfaceBg,
        AppTheme.darkSurfaceCard,
        AppTheme.darkSurfaceRaised,
      ]) {
        expect(c.a, 1.0, reason: '$c must not be translucent');
      }
    });
  });

  group('greeting colour', () {
    double contrast(Color fg, Color bg) {
      final a = fg.computeLuminance();
      final b = bg.computeLuminance();
      final lighter = a > b ? a : b;
      final darker = a > b ? b : a;
      return (lighter + 0.05) / (darker + 0.05);
    }

    test('the light variant is readable on the light ground', () {
      // #4FC3F7 itself is a 64%-lightness sky blue and all but vanishes on a
      // morning sky, which is why light mode uses a darker partner.
      expect(
        contrast(AppTheme.greetingLight, AppTheme.lightSurfaceBg),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('the dark variant is readable on the dark ground', () {
      expect(
        contrast(AppTheme.greetingDark, AppTheme.darkSurfaceBg),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('the dark variant is the colour that was specified', () {
      expect(AppTheme.greetingDark, const Color(0xFF4FC3F7));
    });
  });
}
