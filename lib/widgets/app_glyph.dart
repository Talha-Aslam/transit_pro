import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Draws a card's small leading icon.
///
/// Every screen in this app labels its rows, tiles and status cards with a
/// short emoji string (`icon: '📞'`, `icon: '✅'`). Emoji are drawn by the
/// system font, which means they ignore the theme, change shape between
/// Android versions, carry their own colour, and sit on a different optical
/// baseline from the text beside them — all of which showed up as soon as
/// the surfaces behind them became flat and quiet.
///
/// This maps each glyph the app actually uses to a Material icon and draws
/// that instead, in whatever colour the caller wants. The `String` API is
/// kept deliberately: roughly a hundred call sites pass these glyphs, and
/// they all keep working untouched. An unmapped glyph falls back to drawing
/// the original text, so nothing can disappear.
class AppGlyph extends StatelessWidget {
  final String glyph;
  final double size;
  final Color? color;

  const AppGlyph(this.glyph, {super.key, this.size = 20, this.color});

  @override
  Widget build(BuildContext context) {
    final icon = glyphIcon(glyph);
    if (icon == null) {
      return Text(glyph, style: TextStyle(fontSize: size, height: 1));
    }
    return Icon(icon, size: size, color: color ?? context.textPrimary);
  }
}

/// The Material icon that stands in for [glyph], or null when there is no
/// sensible match and the glyph should simply be drawn as text.
IconData? glyphIcon(String glyph) {
  // Emoji arrive with and without the U+FE0F variation selector depending on
  // which call site wrote them; look up the bare codepoint.
  final key = glyph.replaceAll('️', '').trim();
  return _map[key];
}

const Map<String, IconData> _map = {
  // Status and confirmation
  '✅': Icons.check_circle_rounded,
  '❌': Icons.cancel_rounded,
  '✖': Icons.close_rounded,
  '⚠': Icons.warning_amber_rounded,
  '🚨': Icons.sos_rounded,
  '🛑': Icons.stop_circle_rounded,
  '⏳': Icons.hourglass_bottom_rounded,
  '🕐': Icons.schedule_rounded,
  '⏱': Icons.timer_rounded,
  '⚡': Icons.bolt_rounded,
  '🔀': Icons.shuffle_rounded,

  // People
  '👤': Icons.person_rounded,
  '👥': Icons.group_rounded,
  '🧍': Icons.person_pin_circle_rounded,
  '🧒': Icons.child_care_rounded,
  '🎓': Icons.school_rounded,
  '🏫': Icons.school_rounded,

  // Places and travel
  '🏠': Icons.home_rounded,
  '🏡': Icons.home_work_rounded,
  '📍': Icons.place_rounded,
  '🗺': Icons.map_rounded,
  '📏': Icons.straighten_rounded,
  '🚌': Icons.directions_bus_rounded,
  '🚐': Icons.airport_shuttle_rounded,
  '📡': Icons.satellite_alt_rounded,

  // Contact and messaging
  '📞': Icons.call_rounded,
  '📧': Icons.mail_rounded,
  '💬': Icons.chat_bubble_rounded,
  '📢': Icons.campaign_rounded,
  '📬': Icons.markunread_mailbox_rounded,
  '🔔': Icons.notifications_rounded,
  '📲': Icons.phone_iphone_rounded,

  // Documents and money
  '📄': Icons.description_rounded,
  '📋': Icons.assignment_rounded,
  '📜': Icons.history_edu_rounded,
  '📤': Icons.upload_file_rounded,
  '📅': Icons.calendar_month_rounded,
  '💳': Icons.credit_card_rounded,
  '💵': Icons.payments_rounded,
  '💰': Icons.savings_rounded,

  // Account and misc
  '🪪': Icons.badge_rounded,
  '🆔': Icons.badge_rounded,
  '🔐': Icons.lock_rounded,
  '🌐': Icons.language_rounded,
  '❓': Icons.help_outline_rounded,
  '⭐': Icons.star_rounded,
  '🏆': Icons.emoji_events_rounded,
  '🌅': Icons.wb_sunny_rounded,
  '🌇': Icons.wb_twilight_rounded,
  '🌧': Icons.water_drop_rounded,
};
