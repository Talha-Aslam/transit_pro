import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:transit_core/transit_core.dart' hide MissedBusRequest;
import '../../app/driver_data_service.dart';
import '../../app/missed_bus_service.dart';
import '../../app/notification_service.dart';
import '../../app/parent_data_service.dart';
import '../../app/language_provider.dart';
import '../../app/session_service.dart';
import '../../app/tracking_service.dart';
import '../../data/trip_repository.dart';
import '../../models/missed_bus_request.dart';
import '../../theme/app_theme.dart';
import '../../widgets/find_driver_banner.dart';
import '../../widgets/glass_card.dart';

class ParentDashboard extends StatefulWidget {
  final void Function(int) onNavigate;
  final int unreadCount;

  const ParentDashboard({
    super.key,
    required this.onNavigate,
    this.unreadCount = 0,
  });

  @override
  State<ParentDashboard> createState() => _ParentDashboardState();
}

class _ParentDashboardState extends State<ParentDashboard> {
  @override
  void initState() {
    super.initState();
    LanguageProvider.instance.addListener(_onLangChanged);
  }

  @override
  void dispose() {
    LanguageProvider.instance.removeListener(_onLangChanged);
    super.dispose();
  }

  void _onLangChanged() => setState(() {});

  /// Real per-driver pickup/drop-off times for [child], when the assigned
  /// driver's record has already been resolved by
  /// `SessionService._resolveReferences` (child.driver holds the driver's
  /// uid, not a display name — see `ParentDataService._rebuild`). Returns
  /// null before that resolution lands or when no driver is assigned yet, so
  /// the UI can show a placeholder instead of a fabricated time.
  DriverTimingSlots? _timingSlotsFor(ChildInfo? child) {
    if (child == null || child.driver.isEmpty) return null;
    final driver = SessionService.instance.driverFor(child.driver);
    if (driver == null) return null;
    return DriverTimingSlots.fromMap(driver.timingSlots);
  }

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? AppStrings.t('good_morning')
        : hour < 17
        ? AppStrings.t('good_afternoon')
        : AppStrings.t('good_evening');

    final svc = ParentDataService.instance;

    return ValueListenableBuilder<List<ChildInfo>>(
      valueListenable: svc.children,
      builder: (context, children, _) {
        return ValueListenableBuilder<int>(
          valueListenable: svc.selectedChildIndex,
          builder: (context, selIdx, _) {
            final safeIdx = children.isEmpty
                ? 0
                : selIdx.clamp(0, children.length - 1);
            final child = children.isEmpty ? null : children[safeIdx];

            return SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 100),
              child: Column(
                children: [
                  // â”€â”€ Header â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
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
                        Expanded(
                          child: ValueListenableBuilder(
                            valueListenable: svc.parentInfo,
                            builder: (_, info, _) => Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text(
                                      '👋',
                                      style: TextStyle(fontSize: 18),
                                    ),
                                    const SizedBox(width: 8),
                                    ShaderMask(
                                      shaderCallback: (bounds) =>
                                          AppTheme.parentGradient.createShader(
                                            Rect.fromLTWH(
                                              0,
                                              0,
                                              bounds.width,
                                              bounds.height,
                                            ),
                                          ),
                                      blendMode: BlendMode.srcIn,
                                      child: Text(
                                        greeting,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  info.name.split(' ').first,
                                  style: TextStyle(
                                    color: context.textPrimary,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Notification button
                        GestureDetector(
                          onTap: () => widget.onNavigate(3),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: context.cardBgElevated,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: context.inputBorder,
                                  ),
                                ),
                                child: Center(
                                  child: Image.asset(
                                    'assets/images/notification_bell_off.png',
                                    width: 28,
                                    height: 28,
                                    fit: BoxFit.contain,
                                    filterQuality: FilterQuality.high,
                                  ),
                                ),
                              ),
                              if (widget.unreadCount > 0)
                                Positioned(
                                  top: -4,
                                  right: -4,
                                  child: Container(
                                    width: 16,
                                    height: 16,
                                    decoration: const BoxDecoration(
                                      color: AppTheme.error,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${widget.unreadCount}',
                                        style: TextStyle(
                                          color: context.textPrimary,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        // â”€â”€ Child selector (only when >1 child) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                        if (children.length > 1) ...[
                          SizedBox(
                            height: 38,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: children.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(width: 8),
                              itemBuilder: (_, i) {
                                final selected = i == safeIdx;
                                return GestureDetector(
                                  onTap: () => svc.selectChild(i),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: selected
                                          ? AppTheme.parentGradient
                                          : null,
                                      color: selected
                                          ? null
                                          : context.cardBgElevated,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: selected
                                            ? Colors.transparent
                                            : context.surfaceBorder,
                                      ),
                                    ),
                                    child: Text(
                                      children[i].name.isEmpty
                                          ? 'Child ${i + 1}'
                                          : children[i].name.split(' ').first,
                                      style: TextStyle(
                                        color: selected
                                            ? Colors.white
                                            : context.textSecondary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // â”€â”€ Child status banner â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                        GlassCard(
                          enableBlur: false,
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.success.withValues(alpha: 0.15),
                              AppTheme.success.withValues(alpha: 0.05),
                            ],
                          ),
                          borderColor: AppTheme.success.withValues(alpha: 0.25),
                          padding: const EdgeInsets.all(18),
                          child: child == null
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    child: Text(
                                      AppStrings.t('no_children_yet'),
                                      style: TextStyle(
                                        color: context.textSecondary,
                                      ),
                                    ),
                                  ),
                                )
                              : Row(
                                  children: [
                                    // Child photo
                                    ValueListenableBuilder<List<File?>>(
                                      valueListenable: svc.childImages,
                                      builder: (_, imgs, _) {
                                        final file = safeIdx < imgs.length
                                            ? imgs[safeIdx]
                                            : null;
                                        return Container(
                                          width: 62,
                                          height: 62,
                                          decoration: BoxDecoration(
                                            color: AppTheme.parentPurple
                                                .withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            border: Border.all(
                                              color: AppTheme.success
                                                  .withValues(alpha: 0.4),
                                              width: 2,
                                            ),
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            child: file != null
                                                ? Image.file(
                                                    file,
                                                    width: 62,
                                                    height: 62,
                                                    fit: BoxFit.cover,
                                                  )
                                                : Image.asset(
                                                    'assets/images/profile/boy_transparent.gif',
                                                    width: 62,
                                                    height: 62,
                                                    fit: BoxFit.contain,
                                                    filterQuality:
                                                        FilterQuality.high,
                                                  ),
                                          ),
                                        );
                                      },
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  child.name.isEmpty
                                                      ? 'Unnamed Child'
                                                      : child.name,
                                                  style: TextStyle(
                                                    color: context.textPrimary,
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 3),
                                                Text(
                                                  [child.grade, child.school]
                                                      .where(
                                                        (s) => s.isNotEmpty,
                                                      )
                                                      .join(' Â· '),
                                                  style: TextStyle(
                                                    color:
                                                        context.textSecondary,
                                                    fontSize: 12,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          StatusBadge(
                                            label: AppStrings.t('on_the_bus'),
                                            color: AppTheme.success,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                        const SizedBox(height: 12),

                        // â”€â”€ Live ETA card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                        GlassCard(
                          enableBlur: false,
                          onTap: () => widget.onNavigate(1),
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.parentPurple.withValues(alpha: 0.2),
                              AppTheme.parentIndigo.withValues(alpha: 0.08),
                            ],
                          ),
                          borderColor: AppTheme.parentPurple.withValues(
                            alpha: 0.25,
                          ),
                          padding: const EdgeInsets.all(13),
                          child: Row(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  gradient: AppTheme.parentGradient,
                                  borderRadius: BorderRadius.circular(18),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.parentPurple.withValues(
                                        alpha: 0.4,
                                      ),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Image.asset(
                                    'assets/images/path_transparent.gif',
                                    width: 52,
                                    height: 52,
                                    fit: BoxFit.contain,
                                    filterQuality: FilterQuality.high,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      child == null
                                          ? 'N/A'
                                          : '${child.busNumber.toUpperCase()} - ${child.route.toUpperCase()}',
                                      style: TextStyle(
                                        color: context.textSecondary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.baseline,
                                      textBaseline: TextBaseline.alphabetic,
                                      children: [
                                        ShaderMask(
                                          shaderCallback: (b) =>
                                              const LinearGradient(
                                                colors: [
                                                  Color(0xFFA78BFA),
                                                  Color(0xFF60A5FA),
                                                ],
                                              ).createShader(b),
                                          child: ValueListenableBuilder<int>(
                                            valueListenable: TrackingService
                                                .instance
                                                .etaMinutes,
                                            builder: (_, eta, _) => Text(
                                              '$eta min',
                                              style: TextStyle(
                                                color: context.textPrimary,
                                                fontSize: 30,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          AppStrings.t('to_school'),
                                          style: TextStyle(
                                            color: context.textSecondary,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      child == null
                                          ? ''
                                          : '\ud83d\udccd ${AppStrings.t('currently_at')} ${child.stop}',
                                      style: TextStyle(
                                        color: context.textSecondary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: AppTheme.parentAccent.withValues(
                                    alpha: 0.2,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppTheme.parentAccent.withValues(
                                      alpha: 0.3,
                                    ),
                                  ),
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.arrow_forward_ios,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // ── Driver matching ───────────────────────────────
                        const FindDriverBanner(
                          accent: AppTheme.parentPurple,
                          searchRoute: '/parent/find-drivers',
                        ),

                        // ── Missed Bus quick action ────────────────────────
                        ValueListenableBuilder<MissedBusRequest?>(
                          valueListenable:
                              MissedBusService.instance.studentActiveRequest,
                          builder: (_, req, _) {
                            final isActive =
                                req != null &&
                                req.status == RequestStatus.searching;
                            return GestureDetector(
                              onTap: () => context.push('/parent/missed-bus'),
                              child: GlassCard(
                                enableBlur: false,
                                gradient: LinearGradient(
                                  colors: [
                                    AppTheme.error.withValues(alpha: 0.15),
                                    AppTheme.warning.withValues(alpha: 0.08),
                                  ],
                                ),
                                borderColor: isActive
                                    ? AppTheme.error.withValues(alpha: 0.5)
                                    : AppTheme.error.withValues(alpha: 0.2),
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            AppTheme.error,
                                            Color(0xFFFF6B35),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(13),
                                      ),
                                      child: const Center(
                                        child: Text(
                                          '🚌',
                                          style: TextStyle(fontSize: 22),
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
                                            isActive
                                                ? 'Pickup in Progress…'
                                                : 'Child Missed the Bus?',
                                            style: TextStyle(
                                              color: context.textPrimary,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            isActive
                                                ? 'Searching for a nearby bus'
                                                : 'Request a pickup from a nearby bus',
                                            style: TextStyle(
                                              color: context.textSecondary,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isActive)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppTheme.warning.withValues(
                                            alpha: 0.2,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          'ACTIVE',
                                          style: TextStyle(
                                            color: AppTheme.warningLight,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      )
                                    else
                                      Text(
                                        '→',
                                        style: TextStyle(
                                          color: context.textSecondary,
                                          fontSize: 18,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 30),

                        // ── Today's schedule ──────────────────────────────────────────
                        Builder(
                          builder: (context) {
                            // Real pickup/drop-off times, sourced from the
                            // assigned driver's own `timingSlots` once
                            // SessionService has resolved that driver (see
                            // _timingSlotsFor). "Done"/"Pending" stays a
                            // placeholder: turning it into a real boarded/
                            // not-boarded flag needs today's attendance
                            // record, which is part of the same trip-data gap
                            // noted above the stats grid.
                            final slots = _timingSlotsFor(child);
                            return GlassCard(
                              enableBlur: false,
                              padding: const EdgeInsets.all(18),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        AppStrings.t('todays_schedule'),
                                        style: TextStyle(
                                          color: context.textPrimary,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () => widget.onNavigate(2),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppTheme.parentAccent
                                                .withValues(alpha: 0.15),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                              color: AppTheme.parentAccent
                                                  .withValues(alpha: 0.3),
                                            ),
                                          ),
                                          child: Text(
                                            AppStrings.t('view_all'),
                                            style: TextStyle(
                                              color: AppTheme.parentAccent,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  Row(
                                    children: [
                                      _ScheduleChip(
                                        icon:
                                            'assets/images/schedule/waiting_for_bus_transparent.png',
                                        label: AppStrings.t('pickup'),
                                        time: slots == null
                                            ? '—'
                                            : formatTimeOfDay(
                                                slots.morningPickupFromHome,
                                              ),
                                        status: AppStrings.t('done'),
                                        color: AppTheme.success,
                                      ),
                                      const SizedBox(width: 8),
                                      _ScheduleChip(
                                        icon:
                                            'assets/images/schedule/at_school.png',
                                        label: AppStrings.t('at_school'),
                                        time: slots == null
                                            ? '—'
                                            : formatTimeOfDay(
                                                slots.morningDropoffAtSchool,
                                              ),
                                        status: AppStrings.t('done'),
                                        color: AppTheme.success,
                                      ),
                                      const SizedBox(width: 8),
                                      _ScheduleChip(
                                        icon:
                                            'assets/images/schedule/drop_off_transparent.png',
                                        label: AppStrings.t('drop_off'),
                                        time: slots == null
                                            ? '—'
                                            : formatTimeOfDay(
                                                slots.afternoonDropoffAtHome,
                                              ),
                                        status: AppStrings.t('pending'),
                                        color: AppTheme.warning,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 12),

                        // ── Stats row ──────────────────────────────────────
                        // Family-wide (spans every child, not just the
                        // selected one) — matches the child selector above,
                        // which only changes what the ETA/schedule cards show.
                        // "Safe Rides" was dropped rather than kept as a
                        // fabricated duplicate of on-time: nothing in
                        // Trip/AttendanceRecord tracks a safety signal
                        // independent of on-time yet (Trip.deviationEvents is
                        // reserved for a safety layer that doesn't exist),
                        // and a fourth invented number is worse than three
                        // honest ones.
                        _StatsRow(children: children),
                        const SizedBox(height: 20),

                        // â”€â”€ Recent alerts â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                        ValueListenableBuilder<List<AppNotification>>(
                          valueListenable:
                              NotificationService.instance.history,
                          builder: (context, history, _) {
                            // Sourced from NotificationService.history (the
                            // same stream parent_notifications.dart reads),
                            // newest first -- no more invented boarding/delay
                            // strings.
                            final recent = history.take(3).toList();
                            return GlassCard(
                              enableBlur: false,
                              padding: const EdgeInsets.all(18),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        AppStrings.t('recent_alerts'),
                                        style: TextStyle(
                                          color: context.textPrimary,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () => widget.onNavigate(3),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppTheme.parentAccent
                                                .withValues(alpha: 0.15),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                              color: AppTheme.parentAccent
                                                  .withValues(alpha: 0.3),
                                            ),
                                          ),
                                          child: Text(
                                            AppStrings.t('view_all'),
                                            style: TextStyle(
                                              color: AppTheme.parentAccent,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  if (recent.isEmpty)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 6,
                                      ),
                                      child: Text(
                                        'No recent alerts.',
                                        style: TextStyle(
                                          color: context.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    )
                                  else
                                    ...recent.map(
                                      (n) => Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 8,
                                        ),
                                        child: _AlertRow(
                                          icon: n.icon,
                                          msg: n.message,
                                          time: n.time,
                                          color: n.color,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// Family-wide trip stats (total rides, on-time %, rides this week), computed
/// from real attendance/trip data rather than the old invented trip list.
///
/// Fetches once per distinct set of child ids (not on every parent-dashboard
/// rebuild — a greeting-clock tick or notification arriving shouldn't
/// re-query Firestore) and defaults every figure to 0 while loading or for a
/// family with no attendance history at all, which is the actual bug this
/// replaces.
class _StatsRow extends StatefulWidget {
  final List<ChildInfo> children;

  const _StatsRow({required this.children});

  @override
  State<_StatsRow> createState() => _StatsRowState();
}

class _StatsRowState extends State<_StatsRow> {
  Future<_FamilyTripStats>? _future;
  List<String> _lastChildIds = const [];

  @override
  void initState() {
    super.initState();
    _scheduleLoad();
  }

  @override
  void didUpdateWidget(_StatsRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleLoad();
  }

  void _scheduleLoad() {
    final ids = widget.children
        .map((c) => c.id)
        .where((id) => id.isNotEmpty)
        .toList();
    if (_listEquals(ids, _lastChildIds)) return;
    _lastChildIds = ids;
    _future = _loadFamilyTripStats(ids);
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_FamilyTripStats>(
      future: _future,
      builder: (context, snapshot) {
        final stats = snapshot.data ?? const _FamilyTripStats();
        return Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: 'assets/images/stats/total_trips.png',
                label: AppStrings.t('total_trips'),
                value: '${stats.totalTrips}',
                color: AppTheme.purple,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                icon: 'assets/images/stats/on_time.png',
                label: AppStrings.t('on_time'),
                value: '${stats.onTimePct}%',
                color: AppTheme.success,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                icon: 'assets/images/stats/calendar.png',
                label: AppStrings.t('this_week'),
                value: '${stats.thisWeek}',
                color: AppTheme.info,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _FamilyTripStats {
  final int totalTrips;
  final int onTimePct;
  final int thisWeek;

  const _FamilyTripStats({
    this.totalTrips = 0,
    this.onTimePct = 0,
    this.thisWeek = 0,
  });
}

/// Aggregates every child's attendance across the whole family — the four
/// stat tiles above the "Today's Schedule" card summarise the household, not
/// whichever single child is selected in the chip row.
///
/// `totalTrips` counts attendance records marked [AttendanceStatus.boarded] —
/// a trip the child actually rode, not one they were merely scheduled for.
/// `onTimePct` needs the parent [Trip]'s on-time verdict, which
/// [AttendanceRecord] does not carry itself, so boarded trips are fetched by
/// id (deduplicated, in parallel) to read [Trip.onTime]; a trip still in
/// progress (verdict not yet set) is excluded from the percentage rather than
/// counted as late. `thisWeek` prefers each trip's real [Trip.startedAt] and
/// falls back to the attendance record's own `markedAt` when a trip fetch
/// comes back empty.
Future<_FamilyTripStats> _loadFamilyTripStats(List<String> childIds) async {
  if (childIds.isEmpty) return const _FamilyTripStats();

  final allRecords = <AttendanceRecord>[];
  for (final id in childIds) {
    try {
      allRecords.addAll(
        await TripRepository.instance.fetchAttendanceForStudent(id),
      );
    } catch (_) {
      // Leave this child's contribution as absent rather than fail the whole
      // family's stats over one unreadable child.
    }
  }

  final boarded = allRecords
      .where((r) => r.status == AttendanceStatus.boarded)
      .toList();
  if (boarded.isEmpty) return const _FamilyTripStats();

  final tripIds = boarded
      .map((r) => r.tripId)
      .where((id) => id.isNotEmpty)
      .toSet();
  final trips = <String, Trip>{};
  if (tripIds.isNotEmpty) {
    final fetched = await Future.wait(
      tripIds.map((id) async {
        try {
          return await TripRepository.instance.watchTrip(id).first;
        } catch (_) {
          return null;
        }
      }),
    );
    for (final t in fetched) {
      if (t != null) trips[t.id] = t;
    }
  }

  final rated = boarded.where((r) => trips[r.tripId]?.onTime != null);
  final onTimeCount = rated.where((r) => trips[r.tripId]!.onTime == true).length;
  final ratedCount = rated.length;
  final onTimePct = ratedCount == 0
      ? 0
      : ((onTimeCount / ratedCount) * 100).round();

  final weekAgo = DateTime.now().subtract(const Duration(days: 7));
  final thisWeek = boarded.where((r) {
    final when = trips[r.tripId]?.startedAt ?? r.markedAt;
    return when != null && when.isAfter(weekAgo);
  }).length;

  return _FamilyTripStats(
    totalTrips: boarded.length,
    onTimePct: onTimePct,
    thisWeek: thisWeek,
  );
}

class _StatCard extends StatelessWidget {
  final String icon, label, value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      enableBlur: false,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.27)),
            ),
            child: Center(
              child: Image.asset(
                icon,
                width: 26,
                height: 26,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(color: context.textSecondary, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleChip extends StatelessWidget {
  final String icon, label, time, status;
  final Color color;

  const _ScheduleChip({
    required this.icon,
    required this.label,
    required this.time,
    required this.status,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.cardBgElevated),
        ),
        child: Column(
          children: [
            Image.asset(
              icon,
              width: 32,
              height: 32,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
            const SizedBox(height: 5),
            Text(
              label,
              style: TextStyle(color: context.textSecondary, fontSize: 10),
            ),
            const SizedBox(height: 3),
            Text(
              time,
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Text(
                status,
                style: TextStyle(
                  color: color,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlertRow extends StatelessWidget {
  // `icon` is an emoji (from AppNotification.icon), not an asset path — real
  // notifications carry an emoji glyph rather than a bundled image.
  final String icon, msg, time;
  final Color color;

  const _AlertRow({
    required this.icon,
    required this.msg,
    required this.time,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.cardBg),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.25)),
            ),
            child: Center(
              child: Text(icon, style: const TextStyle(fontSize: 16)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  msg,
                  style: TextStyle(color: context.textPrimary, fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  time,
                  style: TextStyle(color: context.textTertiary, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
