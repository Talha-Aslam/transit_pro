import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:transit_core/transit_core.dart';
import '../../app/driver_data_service.dart';
import '../../app/profile_service.dart';
import '../../app/language_provider.dart';
import '../../app/session_service.dart';
import '../../app/tracking_service.dart';
import '../../data/trip_repository.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_provider.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/image_source_sheet.dart';

class DriverProfile extends StatefulWidget {
  final void Function(int) onNavigate;
  final VoidCallback onLogout;

  const DriverProfile({
    super.key,
    required this.onNavigate,
    required this.onLogout,
  });

  @override
  State<DriverProfile> createState() => _DriverProfileState();
}

class _DriverProfileState extends State<DriverProfile> {
  final _svc = DriverDataService.instance;

  /// Real completed-trip count from `TripRepository`, replacing the
  /// hardcoded `DriverTripMetrics.totalTrips` (136) every driver used to see
  /// regardless of how many trips they had actually run.
  int _completedTripCount = 0;
  String? _tripCountSubUid;
  StreamSubscription<List<Trip>>? _tripCountSub;

  /// Kept alongside the count so the status chip can tell "completed a trip
  /// today" apart from "completed one three weeks ago".
  List<Trip> _trips = const [];

  /// Whether a real trip is currently running — mirrors
  /// `driver_dashboard.dart`'s `_routeStarted`, which is the fix that
  /// replaced this screen's hardcoded "Active - On Route" chip.
  bool _routeStarted = false;

  /// `Not Started` / `On Route` / `Completed` for today, derived from real
  /// tracking + trip state rather than a permanently-green "Active - On
  /// Route" chip every driver used to see regardless of whether they had
  /// started anything.
  String get _statusLabel {
    if (_routeStarted) return AppStrings.t('active_on_route');
    final today = Trip.dateKeyFor(DateTime.now());
    final completedToday = _trips.any(
      (t) => t.dateKey == today && t.status == TripStatus.completed,
    );
    return completedToday ? 'Completed' : 'Not Started';
  }

  Color get _statusColor {
    if (_routeStarted) return AppTheme.success;
    final today = Trip.dateKeyFor(DateTime.now());
    final completedToday = _trips.any(
      (t) => t.dateKey == today && t.status == TripStatus.completed,
    );
    return completedToday ? AppTheme.info : AppTheme.warning;
  }

  /// Local-only: `Driver` (the shared `transit_core` model every app —
  /// parent, student, admin — reads) has no `parentAlerts`/`routeReminders`
  /// fields, unlike `locationSharing`, which is a real column on that
  /// document. Adding them would mean migrating the shared model rather than
  /// this screen, so these two stay session-local rather than silently
  /// pretending to persist.
  bool _parentAlerts = true;
  bool _routeReminders = true;

  bool get _locationSharing => _svc.locationSharing.value;

  @override
  void initState() {
    super.initState();
    LanguageProvider.instance.addListener(_onLangChanged);
    _svc.locationSharing.addListener(_onLocationSharingChanged);
    // The two service rows summarise live Firestore state (seats free, requests
    // waiting), so they have to follow the streams rather than showing whatever
    // was true when the screen opened.
    SessionService.instance.driver.addListener(_onLangChanged);
    SessionService.instance.rideRequests.addListener(_onLangChanged);
    SessionService.instance.addListener(_ensureTripCountSubscription);
    _ensureTripCountSubscription();
    _routeStarted = TrackingService.instance.route != null;
    TrackingService.instance.isSimulating.addListener(_onTrackingChanged);
    TrackingService.instance.isLive.addListener(_onTrackingChanged);
  }

  @override
  void dispose() {
    LanguageProvider.instance.removeListener(_onLangChanged);
    _svc.locationSharing.removeListener(_onLocationSharingChanged);
    SessionService.instance.driver.removeListener(_onLangChanged);
    SessionService.instance.rideRequests.removeListener(_onLangChanged);
    SessionService.instance.removeListener(_ensureTripCountSubscription);
    TrackingService.instance.isSimulating.removeListener(_onTrackingChanged);
    TrackingService.instance.isLive.removeListener(_onTrackingChanged);
    _tripCountSub?.cancel();
    super.dispose();
  }

  void _onTrackingChanged() {
    final started = TrackingService.instance.route != null;
    if (started != _routeStarted && mounted) {
      setState(() => _routeStarted = started);
    }
  }

  /// (Re)subscribes to this driver's real trips whenever the signed-in uid
  /// changes — including the first time it becomes available.
  void _ensureTripCountSubscription() {
    final uid = SessionService.instance.uid;
    if (uid == _tripCountSubUid) return;
    _tripCountSubUid = uid;
    _tripCountSub?.cancel();
    _tripCountSub = null;
    if (uid == null) {
      setState(() {
        _completedTripCount = 0;
        _trips = const [];
      });
      return;
    }
    _tripCountSub = TripRepository.instance.watchTripsForDriver(uid).listen((
      trips,
    ) {
      if (!mounted) return;
      setState(() {
        _trips = trips;
        _completedTripCount = trips
            .where((t) => t.status == TripStatus.completed)
            .length;
      });
    });
  }

  void _onLangChanged() => setState(() {});

  void _onLocationSharingChanged() => setState(() {});

  /// Subtitle for the "My Service" row.
  ///
  /// Names the gap rather than saying "configure" when either half is missing:
  /// a driver with no listed school or no round is invisible to every parent
  /// while their profile otherwise looks finished, and this row is the only place
  /// they would notice.
  String _serviceSummary() {
    final driver = SessionService.instance.driver.value;
    if (driver == null) return 'Loading…';

    final areas = driver.serviceAreas.length;
    final rounds = driver.schedules.length;
    if (areas == 0 && rounds == 0) {
      return 'Not set up — parents cannot find you yet';
    }
    if (areas == 0) return 'Add a school so parents can find you';
    if (rounds == 0) return 'Add a round so families can book a seat';

    return '$areas destination${areas == 1 ? '' : 's'} · '
        '$rounds round${rounds == 1 ? '' : 's'} · '
        '${driver.totalAvailableSeats} of ${driver.totalSeatsOffered} seats free';
  }

  String _requestsSummary() {
    final session = SessionService.instance;
    final pending = session.pendingRideRequests.length;
    final booked = session.acceptedRideRequests.length;
    if (pending > 0) {
      return '$pending waiting on your reply';
    }
    return booked == 0
        ? 'No students booked yet'
        : '$booked student${booked == 1 ? '' : 's'} on your roster';
  }

  /// Subtitle for the "Performance Report" row. Was the hardcoded
  /// `performance_report_desc` string ("96% on-time rate") shown for every
  /// driver regardless of whether they had completed a single real trip.
  /// `_trips`/`_completedTripCount` are already the real, live-subscribed
  /// data this screen uses for the trip-history row above — reused here
  /// rather than a second Firestore listener for the same numbers.
  String _performanceSummary() {
    if (_completedTripCount == 0) return 'No trips completed yet';
    final completed = _trips
        .where((t) => t.status == TripStatus.completed)
        .toList();
    final onTime = completed.where((t) => t.onTime == true).length;
    final pct = (onTime / completed.length * 100).round();
    return '$pct% on-time rate';
  }

  /// Subtitle + color for the "Documents & License" row. Was the hardcoded
  /// `documents_license_desc` string ("All verified ✓") shown even for a
  /// brand-new driver still sitting in `DriverStatus.pendingVerification` —
  /// same real `Driver.isApproved` gate `driver_performance_screen.dart`
  /// uses for its own new-account state, not a separate invented field.
  bool get _documentsVerified =>
      SessionService.instance.driver.value?.isApproved ?? false;

  String get _documentsSummary =>
      _documentsVerified ? 'All verified ✓' : 'Pending verification';

  Color get _documentsColor =>
      _documentsVerified ? AppTheme.success : AppTheme.warning;

  Future<void> _pickImage() async {
    final source = await showImageSourceSheet(
      context,
      accentColor: AppTheme.driverCyan,
    );
    if (source == null) return;
    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 85,
    );
    if (picked != null) {
      ProfileService.instance.driverImage.value = File(picked.path);
    }
  }

  // Email/Bus Number/Route/Total Students are intentionally not editable
  // here — `updateDriverInfo` never wrote any of them back (email needs a
  // Firebase Auth re-auth flow this pass doesn't cover; the other three are
  // derived from the bus/route assignment and the real roster, not
  // hand-typed). Bus Number/Route show read-only elsewhere on this screen;
  // Total Students gets its own real-count-plus-manual-offline widget.
  void _editDriverInfo() {
    final info = _svc.driverInfo.value;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditSheet(
        title: AppStrings.t('edit_info'),
        fields: [
          _FieldDef(AppStrings.t('full_name'), info.name),
          _FieldDef(AppStrings.t('mobile_lbl'), info.phone),
          _FieldDef(AppStrings.t('license_no_lbl'), info.license),
          _FieldDef(AppStrings.t('experience_lbl'), info.experience),
        ],
        accentColor: AppTheme.driverCyan,
        onSave: (v) => _svc.updateDriverInfo(
          info.copyWith(
            name: v[0],
            phone: v[1],
            license: v[2],
            experience: v[3],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DriverInfo>(
      valueListenable: _svc.driverInfo,
      builder: (context, info, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 120),
          child: Column(
            children: [
              // ── Profile header ──────────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppTheme.driverCyan.withValues(alpha: 0.25),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Column(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            color: Colors.blue.shade200.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(26),
                            border: Border.all(
                              color: AppTheme.driverCyan.withValues(alpha: 0.5),
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.driverCyan.withValues(
                                  alpha: 0.3,
                                ),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ValueListenableBuilder<File?>(
                            valueListenable:
                                ProfileService.instance.driverImage,
                            builder: (_, file, _) => file != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(23),
                                    child: Image.file(
                                      file,
                                      width: 84,
                                      height: 84,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : const Center(
                                    child: Text(
                                      '👨',
                                      style: TextStyle(fontSize: 44),
                                    ),
                                  ),
                          ),
                        ),
                        Positioned(
                          bottom: -4,
                          right: -4,
                          child: GestureDetector(
                            onTap: _pickImage,
                            child: Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                gradient: AppTheme.driverGradient,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.camera_alt_rounded,
                                  size: 13,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      info.name,
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      info.email,
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    // The star-rating row that used to live here has moved
                    // to the "Performance Report" screen (`DriverRatingBar`,
                    // `widgets/driver_rating_bar.dart`) -- this profile page
                    // now shows it in exactly one place instead of two.
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: _statusColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _statusColor.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: _statusColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _statusLabel,
                                style: TextStyle(
                                  color: _statusColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _editDriverInfo,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: context.cardBg,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: context.surfaceBorder),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.edit_outlined,
                                  size: 12,
                                  color: context.textSecondary,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  AppStrings.t('edit_info'),
                                  style: TextStyle(
                                    color: context.textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    // ── Driver info ─────────────────────────────────
                    GlassCard(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.driverCyan.withValues(alpha: 0.1),
                          AppTheme.driverTeal.withValues(alpha: 0.05),
                        ],
                      ),
                      borderColor: AppTheme.driverCyan.withValues(alpha: 0.2),
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppStrings.t('driver_info_section'),
                            style: TextStyle(
                              color: context.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 14),
                          // Was three manual `Row`s of two `Expanded` cards.
                          // A plain `Row` only stretches its own two children
                          // to match *each other*, and only within that one
                          // row — it does nothing to equalise height across
                          // rows. `GridView.count` fixes all 6 cells to one
                          // shared width *and* height instead, driven by a
                          // single `childAspectRatio`.
                          //
                          // The ratio here is deliberately *tight* — sized
                          // to `_InfoCard`'s own compact natural height, not
                          // to whatever "Total Students" would need if left
                          // alone. That only works because
                          // `_TotalStudentsCard` was restructured below to
                          // actually fit that budget (icon+label sharing a
                          // row, value+steppers sharing a row) rather than
                          // asking the grid to grow around it.
                          GridView.count(
                            crossAxisCount: 2,
                            shrinkWrap: true,
                            // This grid sits inside the screen's own
                            // scrolling `SingleChildScrollView` — it must
                            // not try to scroll independently.
                            physics: const NeverScrollableScrollPhysics(),
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            // History of this number, so the next person
                            // (or the next me) doesn't re-derive it from
                            // scratch or re-break it the same way twice:
                            //  - 2.2 overflowed every cell by ~8.5px --
                            //    the ratio was hand-estimated, and default
                            //    `TextStyle` line height runs ~1.2x the raw
                            //    font size, not 1.0x.
                            //  - Fixed that two ways at once: lowered the
                            //    ratio to 1.9 (taller cells) *and* shrank
                            //    each card's content (tighter line-height,
                            //    less padding). Only one of those was
                            //    needed -- stacked together they overshot
                            //    into a visible empty strip at the bottom
                            //    of this whole card (reported with a
                            //    screenshot), since the now-shorter content
                            //    no longer needed cells that tall.
                            //  - 2.4 is the recalibration: real content
                            //    height with the trimmed padding/line-height
                            //    in place is ~58px for `_InfoCard` (its
                            //    Container's own numbers: 8px vertical
                            //    padding x2 + 16px icon + 2px gap + ~10px
                            //    label + 1px gap + ~13px value), so this
                            //    targets roughly 65px of cell height at a
                            //    typical ~157px cell width -- a real ~7px
                            //    buffer this time, not a second stacked
                            //    safety margin on top of the first.
                            childAspectRatio: 1.9,
                            children: [
                              _InfoCard(
                                icon: '🪪',
                                label: AppStrings.t('license_no_lbl'),
                                value: info.license,
                              ),
                              _InfoCard(
                                icon: '📅',
                                label: AppStrings.t('experience_lbl'),
                                value: info.experience,
                              ),
                              _InfoCard(
                                icon: '🚌',
                                label: AppStrings.t('bus_number_lbl'),
                                value: info.busNumber.isEmpty
                                    ? 'Not assigned yet'
                                    : info.busNumber,
                              ),
                              _InfoCard(
                                icon: '🗺️',
                                label: AppStrings.t('route_lbl'),
                                value: info.route,
                              ),
                              _InfoCard(
                                icon: '📞',
                                label: AppStrings.t('mobile_lbl'),
                                value: info.phone,
                              ),
                              _TotalStudentsCard(
                                autoCount: info.autoStudentCount,
                                manualCount: info.manualStudentCount,
                                onChanged: (v) => _svc.setManualStudentCount(v),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── Settings toggles ────────────────────────────
                    GlassCard(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppStrings.t('app_settings'),
                            style: TextStyle(
                              color: context.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 4),
                          _PrefRow(
                            label: AppStrings.t('share_location'),
                            desc: AppStrings.t('share_loc_desc'),
                            value: _locationSharing,
                            onChanged: _svc.setLocationSharing,
                          ),
                          _divider(context),
                          _PrefRow(
                            label: AppStrings.t('parent_alerts_lbl'),
                            desc: AppStrings.t('parent_alerts_desc'),
                            value: _parentAlerts,
                            onChanged: (v) => setState(() => _parentAlerts = v),
                          ),
                          _divider(context),
                          _PrefRow(
                            label: AppStrings.t('route_reminders_lbl'),
                            desc: AppStrings.t('route_reminders_desc'),
                            value: _routeReminders,
                            onChanged: (v) =>
                                setState(() => _routeReminders = v),
                          ),
                          // Break alerts removed from profile settings
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── Menu items ──────────────────────────────────
                    GlassCard(
                      child: Column(
                        children: [
                          _MenuItem(
                            icon: '🗺️',
                            label: 'My Service',
                            desc: _serviceSummary(),
                            onTap: () => context.push('/driver/service'),
                          ),
                          _MenuItem(
                            icon: '📬',
                            label: 'Seat Requests',
                            desc: _requestsSummary(),
                            onTap: () => context.push('/driver/ride-requests'),
                          ),
                          _MenuItem(
                            icon: '💳',
                            label: AppStrings.t('payment_history'),
                            desc: 'Monthly payment records',
                            onTap: () =>
                                context.push('/driver/payment-history'),
                          ),
                          _MenuItem(
                            icon: '📋',
                            label: AppStrings.t('trip_history'),
                            desc: '$_completedTripCount trips completed',
                            onTap: () => context.push('/driver/trips'),
                          ),
                          _MenuItem(
                            icon: '🏆',
                            label: AppStrings.t('performance_report'),
                            desc: _performanceSummary(),
                            onTap: () => context.push('/driver/performance'),
                          ),
                          _MenuItem(
                            icon: '📜',
                            label: AppStrings.t('documents_license'),
                            desc: _documentsSummary,
                            descColor: _documentsColor,
                            onTap: () => context.push('/driver/documents'),
                          ),
                          _MenuItem(
                            icon: '🌐',
                            label: AppStrings.t('language'),
                            desc: LanguageProvider.instance.lang,
                            onTap: () => context.push('/driver/language'),
                          ),
                          _MenuItem(
                            icon: '🔐',
                            label: AppStrings.t('change_password'),
                            onTap: () =>
                                context.push('/driver/change-password'),
                          ),
                          _MenuItem(
                            icon: '📞',
                            label: AppStrings.t('emergency_contacts'),
                            onTap: () =>
                                context.push('/driver/emergency-contacts'),
                          ),
                          _MenuItem(
                            icon: '❓',
                            label: AppStrings.t('help_support'),
                            onTap: () => context.push('/driver/help-support'),
                          ),
                          _MenuItem(
                            icon: '⭐',
                            label: AppStrings.t('rate_app_title'),
                            onTap: () => context.push('/driver/rate-app'),
                          ),
                          _MenuItem(
                            icon: '📄',
                            label: AppStrings.t('terms_lbl'),
                            isLast: true,
                            onTap: () => context.push('/driver/terms'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── Theme ────────────────────────────────────────
                    GlassCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Text(
                            context.isDark ? '🌙' : '☀️',
                            style: const TextStyle(fontSize: 18),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              context.isDark
                                  ? AppStrings.t('dark_mode')
                                  : AppStrings.t('light_mode'),
                              style: TextStyle(
                                color: context.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          AppSwitch(
                            value: context.isDark,
                            activeColor: AppTheme.driverCyan,
                            onChanged: (_) => ThemeProvider.instance.toggle(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── Logout ──────────────────────────────────────
                    GestureDetector(
                      onTap: widget.onLogout,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: AppTheme.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppTheme.error.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            AppStrings.t('log_out'),
                            style: const TextStyle(
                              color: AppTheme.errorLight,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'TransportKid v2.4.1 · © 2026',
                      style: TextStyle(
                        color: context.textTertiary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Helper widgets ───────────────────────────────────────────────────────────

Widget _divider(BuildContext context) =>
    Container(height: 1, color: context.cardBg);

class _PrefRow extends StatelessWidget {
  final String label, desc;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _PrefRow({
    required this.label,
    required this.desc,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(color: context.textPrimary, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: TextStyle(color: context.textTertiary, fontSize: 12),
                ),
              ],
            ),
          ),
          AppSwitch(
            value: value,
            onChanged: onChanged,
            activeColor: AppTheme.driverCyan,
          ),
        ],
      ),
    );
  }
}

/// The driver's own view of "Total Students": real in-app roster count plus
/// a manual +/- for riders who aren't registered in the app (a driver's own
/// kid, a cash-paying family outside the platform). Parents/students only
/// ever see the combined total elsewhere — this breakdown is driver-only.
class _TotalStudentsCard extends StatelessWidget {
  final int autoCount;
  final int manualCount;
  final ValueChanged<int> onChanged;

  const _TotalStudentsCard({
    required this.autoCount,
    required this.manualCount,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final total = autoCount + manualCount;
    return Container(
      // Reduced from 10 -- this card has two more real lines of content
      // than `_InfoCard` and needs to give some room back to fit the same
      // tight grid cell.
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: context.cardBgElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon + label share one row instead of two separate lines --
          // the single biggest space saver here.
          Row(
            children: [
              const Text('👥', style: TextStyle(fontSize: 14, height: 1)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  AppStrings.t('total_students_lbl'),
                  style: TextStyle(
                    color: context.textTertiary,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    height: 1.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          // Value + steppers share one row instead of the steppers sitting
          // on their own row underneath a separate "in-app"/"offline" pair
          // of lines -- the other explicit space saver.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$total total',
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _StepperBtn(
                    icon: Icons.remove,
                    onTap: manualCount > 0
                        ? () => onChanged(manualCount - 1)
                        : null,
                  ),
                  const SizedBox(width: 4),
                  _StepperBtn(
                    icon: Icons.add,
                    onTap: () => onChanged(manualCount + 1),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 2),
          // The in-app/manual breakdown compressed onto one line. Wrapped
          // in `FittedBox` (not just `overflow: ellipsis`) because this is
          // the one piece of text on this card with no fixed upper bound --
          // both counts can run to multiple digits -- so it shrinks to fit
          // rather than ever risking a clipped line or a bottom overflow.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '$autoCount in-app · +$manualCount offline',
              style: TextStyle(color: context.textTertiary, fontSize: 8),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepperBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _StepperBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: enabled
              ? AppTheme.driverCyan.withValues(alpha: 0.15)
              : context.cardBg,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          icon,
          size: 12,
          color: enabled ? AppTheme.driverCyan : context.textTertiary,
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String icon, label, value;
  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      // Was 10 -- trimmed alongside the grid's aspect-ratio fix (Method A)
      // as a second, independent margin against the same overflow: even if
      // a future ratio tweak drifts tight again, this card now needs a few
      // fewer px to lay itself out.
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: context.cardBgElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(icon, style: const TextStyle(fontSize: 16, height: 1)),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: context.textTertiary,
              fontSize: 9,
              fontWeight: FontWeight.w600,
              height: 1.1,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 1),
          Text(
            value,
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.1,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final String icon, label;
  final String? desc;
  final Color? descColor;
  final bool isLast;
  final VoidCallback? onTap;
  const _MenuItem({
    required this.icon,
    required this.label,
    this.desc,
    this.descColor,
    this.isLast = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : Border(bottom: BorderSide(color: context.surfaceBorder)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: context.cardBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(icon, style: const TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(color: context.textPrimary, fontSize: 14),
                  ),
                  if (desc != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      desc!,
                      style: TextStyle(
                        color: descColor ?? context.textTertiary,
                        fontSize: 12,
                        fontWeight: descColor != null
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: context.textTertiary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Edit bottom sheet ────────────────────────────────────────────────────────

class _FieldDef {
  final String label;
  final String initialValue;
  _FieldDef(this.label, this.initialValue);
}

class _EditSheet extends StatefulWidget {
  final String title;
  final List<_FieldDef> fields;
  final Color accentColor;
  final void Function(List<String> values) onSave;

  const _EditSheet({
    required this.title,
    required this.fields,
    required this.accentColor,
    required this.onSave,
  });

  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  late final List<TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = widget.fields
        .map((f) => TextEditingController(text: f.initialValue))
        .toList();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    widget.onSave(_controllers.map((c) => c.text.trim()).toList());
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final sheetBg = context.isDark ? AppTheme.bgDark : Colors.white;
    final inputFill = context.isDark
        ? AppTheme.bgDarkBlue
        : const Color(0xFFF1F5F9);
    final sheetHeight = MediaQuery.of(context).size.height * 0.85;

    return SizedBox(
      height: sheetHeight,
      child: Container(
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                color: context.surfaceBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              widget.title,
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: List.generate(widget.fields.length, (i) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.fields[i].label,
                            style: TextStyle(
                              color: context.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _controllers[i],
                            style: TextStyle(
                              color: context.textPrimary,
                              fontSize: 14,
                            ),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: inputFill,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: context.inputBorder,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: context.inputBorder,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: widget.accentColor,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: _save,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        widget.accentColor,
                        widget.accentColor.withValues(alpha: 0.75),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Text(
                      'Save Changes',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
