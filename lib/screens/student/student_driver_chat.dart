import 'package:flutter/material.dart';

import '../../app/session_service.dart';
import '../../theme/app_theme.dart';
import '../chat/conversation_screen.dart';

/// A student's chat with their driver.
///
/// Was a mirror of the parent screen's in-memory fake, down to the
/// two-second canned reply. Now a thin adapter over [ConversationScreen].
///
/// [driverId] is what makes it real: the old screen only ever had the
/// driver's *name*, which is why it could not have sent anything even if it
/// had tried.
class StudentDriverChat extends StatelessWidget {
  final String driverId;
  final String driverName;
  final String busNumber;

  const StudentDriverChat({
    super.key,
    required this.driverId,
    required this.driverName,
    required this.busNumber,
  });

  @override
  Widget build(BuildContext context) => ConversationScreen(
    peerId: driverId,
    peerName: driverName,
    subtitle: busNumber.trim(),
    // A self-registered student is their own subject, so the thread is
    // keyed the same way a parent's is and the driver's inbox can name them.
    studentId: SessionService.instance.student.value?.id,
    senderRole: 'student',
    accentGradient: AppTheme.parentGradient,
  );
}
