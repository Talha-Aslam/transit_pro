import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/language_provider.dart';
import '../../app/notification_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

class PickupDropoffConfirmationScreen extends StatefulWidget {
  final String childName;
  final String routeType; // 'pickup' or 'dropoff'

  const PickupDropoffConfirmationScreen({
    super.key,
    required this.childName,
    required this.routeType,
  });

  @override
  State<PickupDropoffConfirmationScreen> createState() =>
      _PickupDropoffConfirmationScreenState();
}

class _PickupDropoffConfirmationScreenState
    extends State<PickupDropoffConfirmationScreen>
    with SingleTickerProviderStateMixin {
  bool _confirmed = false;
  bool _loading = false;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    LanguageProvider.instance.addListener(_onLangChanged);
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    LanguageProvider.instance.removeListener(_onLangChanged);
    super.dispose();
  }

  void _onLangChanged() => setState(() {});

  Future<void> _confirmEvent() async {
    setState(() => _loading = true);

    await Future.delayed(const Duration(seconds: 1));

    if (mounted) {
      setState(() {
        _loading = false;
        _confirmed = true;
      });

      // Send notification
      NotificationService.instance.show(
        title: widget.routeType == 'pickup'
            ? '✅ Child Boarded Safely'
            : '✅ Child Reached Destination',
        body:
            '${widget.childName} ${widget.routeType == 'pickup' ? 'has boarded' : 'has arrived at destination'}.',
        type: widget.routeType == 'pickup'
            ? 'pickup_confirmed'
            : 'dropoff_confirmed',
        icon: widget.routeType == 'pickup' ? '📍' : '🏫',
        color: AppTheme.success,
      );

      // Auto-navigate after 2 seconds
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) context.pop();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: context.scaffoldBg,
        child: SafeArea(
          child: Column(
            children: [
              if (!_confirmed)
                // ── Header ──────────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppTheme.parentPurple.withValues(alpha: 0.2),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => context.pop(),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: context.cardBgElevated,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.arrow_back_rounded),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.routeType == 'pickup'
                                  ? 'Pickup Confirmation'
                                  : 'Dropoff Confirmation',
                              style: TextStyle(
                                color: context.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'Confirm ${widget.childName} has boarded',
                              style: TextStyle(
                                color: context.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              if (!_confirmed)
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Animated pulse circle
                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (_, _) => Transform.scale(
                            scale: 1 + (_pulseController.value * 0.2),
                            child: Container(
                              width: 140,
                              height: 140,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppTheme.parentPurple.withValues(
                                  alpha: 0.1 * (1 - _pulseController.value),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: AppTheme.parentPurple.withValues(
                              alpha: 0.15,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              widget.routeType == 'pickup' ? '👧' : '📍',
                              style: const TextStyle(fontSize: 48),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          widget.childName,
                          style: TextStyle(
                            color: context.textPrimary,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.routeType == 'pickup'
                              ? 'Ready to confirm pickup?'
                              : 'Ready to confirm arrival?',
                          style: TextStyle(
                            color: context.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 32),
                        GlassCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: AppTheme.info.withValues(
                                        alpha: 0.15,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Center(
                                      child: Text(
                                        '⏰',
                                        style: TextStyle(fontSize: 20),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Current Time',
                                          style: TextStyle(
                                            color: context.textSecondary,
                                            fontSize: 11,
                                          ),
                                        ),
                                        Text(
                                          _getCurrentTime(),
                                          style: TextStyle(
                                            color: context.textPrimary,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: AppTheme.success.withValues(
                                        alpha: 0.15,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Center(
                                      child: Text(
                                        '📍',
                                        style: TextStyle(fontSize: 20),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Location',
                                          style: TextStyle(
                                            color: context.textSecondary,
                                            fontSize: 11,
                                          ),
                                        ),
                                        Text(
                                          widget.routeType == 'pickup'
                                              ? 'Bus Stop, Gulberg'
                                              : 'School Gate, DHA',
                                          style: TextStyle(
                                            color: context.textPrimary,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: AppTheme.success.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: Text('✅', style: TextStyle(fontSize: 50)),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            widget.routeType == 'pickup'
                                ? 'Pickup Confirmed'
                                : 'Arrival Confirmed',
                            style: TextStyle(
                              color: context.textPrimary,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.routeType == 'pickup'
                                ? '${widget.childName} has boarded safely'
                                : '${widget.childName} has arrived safely',
                            style: TextStyle(
                              color: context.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // ── Action buttons ──────────────────────────────────────────────
              if (!_confirmed)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: _loading ? null : _confirmEvent,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: _loading
                                  ? [Colors.grey, Colors.grey]
                                  : [AppTheme.success, Color(0xFF10B981)],
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Center(
                            child: _loading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.check_circle_rounded,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        widget.routeType == 'pickup'
                                            ? 'Confirm Pickup'
                                            : 'Confirm Arrival',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () => context.pop(),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: context.cardBgElevated,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: context.surfaceBorder),
                          ),
                          child: Center(
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                color: context.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.parentPurple,
                            AppTheme.parentAccent,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Center(
                        child: Text(
                          'Done',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
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

  String _getCurrentTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }
}
