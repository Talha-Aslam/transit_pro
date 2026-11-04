import 'package:flutter/material.dart';

import '../../app/language_provider.dart';
import '../../app/parent_data_service.dart';
import '../../theme/app_theme.dart';
import '../chat/conversation_screen.dart';

/// The parent's chat with the driver carrying their selected child.
///
/// This screen used to keep its messages in a `List` and answer itself two
/// seconds later from a `Timer`, with a canned line naming the driver. The
/// driver was never told a message existed, and had no screen to read one
/// on. It is now a thin adapter over [ConversationScreen], which writes to
/// `chats/{chatId}/messages` and alerts the driver.
class DriverChatScreen extends StatelessWidget {
  const DriverChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final child = ParentDataService.instance.selectedChild;
    final driverName = child?.driverName.trim().isNotEmpty == true
        ? child!.driverName.trim()
        : AppStrings.t('no_driver_assigned');
    final busNumber = child?.busNumber ?? '';

    return ConversationScreen(
      // `child.driver` is the driver's uid; `driverName` is only a display
      // name, and a name is not an account to address a thread to.
      peerId: child?.driver ?? '',
      peerName: driverName,
      subtitle: [
        if ((child?.name ?? '').trim().isNotEmpty) child!.name.trim(),
        if (busNumber.isNotEmpty) busNumber,
      ].join(' · '),
      // The thread is about this child, not about the driver in general.
      studentId: child?.id,
      senderRole: 'parent',
      accentGradient: AppTheme.parentGradient,
    );
  }
}
