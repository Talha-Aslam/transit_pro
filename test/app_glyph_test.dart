import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transit_pro/widgets/app_glyph.dart';

/// Roughly a hundred call sites still pass their leading icon as an emoji
/// string. [AppGlyph] is what turns those into Material icons, so a gap in
/// the map is a system-font emoji sitting in the middle of a themed row.
void main() {
  group('glyphIcon', () {
    test('maps the glyphs the app actually ships', () {
      expect(glyphIcon('📞'), Icons.call_rounded);
      expect(glyphIcon('✅'), Icons.check_circle_rounded);
      expect(glyphIcon('🚌'), Icons.directions_bus_rounded);
      expect(glyphIcon('🔐'), Icons.lock_rounded);
      expect(glyphIcon('💳'), Icons.credit_card_rounded);
    });

    test('ignores the variation selector', () {
      // Some call sites write '⚠️' (with U+FE0F) and others '⚠'. Both have
      // to resolve, or the same warning row looks different on two screens.
      expect(glyphIcon('⚠️'), glyphIcon('⚠'));
      expect(glyphIcon('🗺️'), Icons.map_rounded);
      expect(glyphIcon('⏱️'), Icons.timer_rounded);
    });

    test('tolerates surrounding whitespace', () {
      expect(glyphIcon(' 📍 '), Icons.place_rounded);
    });

    test('returns null for anything unmapped', () {
      expect(glyphIcon('🦄'), isNull);
      expect(glyphIcon(''), isNull);
      expect(glyphIcon('abc'), isNull);
    });
  });

  group('AppGlyph widget', () {
    testWidgets('draws the mapped icon at the requested size and colour',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppGlyph('📞', size: 24, color: Color(0xFF00FF00)),
          ),
        ),
      );

      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, Icons.call_rounded);
      expect(icon.size, 24);
      expect(icon.color, const Color(0xFF00FF00));
    });

    testWidgets('falls back to drawing the glyph itself when unmapped',
        (tester) async {
      // Nothing may silently disappear: an unknown glyph still has to show
      // up as the character it was.
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AppGlyph('🦄', size: 18)),
        ),
      );

      expect(find.byType(Icon), findsNothing);
      expect(find.text('🦄'), findsOneWidget);
    });
  });
}
