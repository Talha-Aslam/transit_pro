import 'package:flutter/material.dart';
import '../../app/driver_data_service.dart';
import '../../app/language_provider.dart';
import '../../app/student_data_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

class StudentSchedule extends StatefulWidget {
  const StudentSchedule({super.key});
  @override
  State<StudentSchedule> createState() => _StudentScheduleState();
}

class _StudentScheduleState extends State<StudentSchedule> {
  int _selectedDay = DateTime.now().weekday - 1; // 0=Mon
  DriverTimingSlots _localTimingSlots = const DriverTimingSlots();
  bool _hasLocalOverrides = false;

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

  bool _isUniversityStudent(StudentInfo info) {
    final school = info.school.toLowerCase();
    final grade = info.grade.toLowerCase();
    return school.contains('university') || grade == 'university';
  }

  DriverTimingSlots _effectiveSlots(
    DriverTimingSlots sharedSlots,
    bool universityStudent,
  ) {
    if (universityStudent) return sharedSlots;
    return _hasLocalOverrides ? _localTimingSlots : sharedSlots;
  }

  Future<void> _showDayOptions(
    BuildContext context,
    int dayIndex,
    DriverTimingSlots slots,
    bool universityStudent,
  ) async {
    final selectedDay = _days[dayIndex];
    var pickupTime = slots.morningPickupFromHome;
    var dropoffTime = slots.afternoonDropoffAtHome;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            Future<void> pickPickupTime() async {
              final picked = await showTimePicker(
                context: sheetContext,
                initialTime: pickupTime,
                helpText: 'Select pickup time',
              );
              if (picked != null) {
                setSheetState(() => pickupTime = picked);
              }
            }

            Future<void> pickDropoffTime() async {
              final picked = await showTimePicker(
                context: sheetContext,
                initialTime: dropoffTime,
                helpText: 'Select drop-off time',
              );
              if (picked != null) {
                setSheetState(() => dropoffTime = picked);
              }
            }

            return SafeArea(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: context.cardBg,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: context.surfaceBorder),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: AppTheme.studentGradient,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Center(child: Text('🗓️')),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                selectedDay,
                                style: TextStyle(
                                  color: context.textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Manage pickup and drop-off time',
                                style: TextStyle(
                                  color: context.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                              if (!universityStudent) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'These changes stay on the student side only',
                                  style: TextStyle(
                                    color: context.textTertiary,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: Icon(
                            Icons.close_rounded,
                            color: context.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _TimeOptionCard(
                      title: 'Pickup Time',
                      subtitle: 'Morning pickup from home',
                      time: formatTimeOfDay(pickupTime),
                      icon: '🏠',
                      color: AppTheme.studentAmber,
                      onTap: pickPickupTime,
                    ),
                    const SizedBox(height: 12),
                    _TimeOptionCard(
                      title: 'Drop-off Time',
                      subtitle: 'Home drop-off after route return',
                      time: formatTimeOfDay(dropoffTime),
                      icon: '🏡',
                      color: AppTheme.success,
                      onTap: pickDropoffTime,
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          final updatedSlots = slots.copyWith(
                            morningPickupFromHome: pickupTime,
                            afternoonDropoffAtHome: dropoffTime,
                          );
                          if (universityStudent) {
                            DriverDataService.instance.setTimingSlots(
                              updatedSlots,
                            );
                          } else {
                            setState(() {
                              _localTimingSlots = updatedSlots;
                              _hasLocalOverrides = true;
                            });
                          }
                          Navigator.pop(sheetContext);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.studentAmber,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Save Changes',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  List<String> get _days => [
    AppStrings.t('day_mon'),
    AppStrings.t('day_tue'),
    AppStrings.t('day_wed'),
    AppStrings.t('day_thu'),
    AppStrings.t('day_fri'),
    AppStrings.t('day_sat'),
  ];

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.t('my_schedule'),
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            AppStrings.t('pickup_dropoff_timings'),
            style: TextStyle(color: context.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<StudentInfo>(
      valueListenable: StudentDataService.instance.studentInfo,
      builder: (context, studentInfo, _) {
        final universityStudent = _isUniversityStudent(studentInfo);
        // Same "no bus assigned yet" signal `parent_schedule.dart` already
        // gates on — without this, a brand-new student with no real driver
        // saw `DriverTimingSlots()`'s hardcoded 7:15/8:00/14:30/15:15
        // defaults as if they were a real schedule.
        final hasBus =
            studentInfo.busNumber.isNotEmpty || studentInfo.route.isNotEmpty;
        if (!hasBus) {
          return SingleChildScrollView(
            child: _NoDriverState(header: _buildHeader(context)),
          );
        }
        return ValueListenableBuilder<DriverTimingSlots>(
          valueListenable: DriverDataService.instance.timingSlots,
          builder: (context, sharedSlots, _) {
            final slots = _effectiveSlots(sharedSlots, universityStudent);
            return SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context),
                  const SizedBox(height: 16),

                  // ── Day selector ──────────────────────────────
                  SizedBox(
                    height: 52,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _days.length,
                      itemBuilder: (ctx, i) {
                        final sel = i == _selectedDay;
                        return GestureDetector(
                          onTap: () async {
                            setState(() => _selectedDay = i);
                            await _showDayOptions(
                              context,
                              i,
                              slots,
                              universityStudent,
                            );
                          },
                          child: Container(
                            width: 52,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              gradient: sel ? AppTheme.studentGradient : null,
                              color: sel ? null : context.cardBg,
                              borderRadius: BorderRadius.circular(14),
                              border: sel
                                  ? null
                                  : Border.all(color: context.cardBgElevated),
                            ),
                            child: Center(
                              child: Text(
                                _days[i],
                                style: TextStyle(
                                  color: sel
                                      ? Colors.white
                                      : context.textSecondary,
                                  fontWeight: sel
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Route info card ───────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: GlassCard(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.studentAmber.withValues(alpha: 0.10),
                          AppTheme.studentOrange.withValues(alpha: 0.04),
                        ],
                      ),
                      borderColor: AppTheme.studentAmber.withValues(alpha: 0.2),
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: AppTheme.studentGradient,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Center(
                              child: Text('🚌', style: TextStyle(fontSize: 22)),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  [
                                    studentInfo.route,
                                    studentInfo.busNumber,
                                  ].where((s) => s.isNotEmpty).join(' · '),
                                  style: TextStyle(
                                    color: context.textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${AppStrings.t('your_stop')}: ${studentInfo.stop}',
                                  style: TextStyle(
                                    color: AppTheme.studentAccent,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          StatusBadge(
                            label: AppStrings.t('active_status'),
                            color: AppTheme.success,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Morning schedule ──────────────────────────
                  _SectionLabel(label: AppStrings.t('morning_pickup_s')),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: GlassCard(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        children: [
                          _TimelineItem(
                            icon: '🏠',
                            title: AppStrings.t('be_at_stop'),
                            subtitle: 'Home to school / college / university',
                            time: formatTimeOfDay(slots.morningPickupFromHome),
                            color: AppTheme.studentAmber,
                            isFirst: true,
                          ),
                          _TimelineItem(
                            icon: '🚌',
                            title: AppStrings.t('bus_arrives'),
                            subtitle: 'Estimated pickup',
                            time: formatTimeOfDay(slots.morningPickupFromHome),
                            color: AppTheme.info,
                          ),
                          _TimelineItem(
                            icon: '🏫',
                            title: AppStrings.t('reach_school'),
                            subtitle: 'School / college / university drop-off',
                            time: formatTimeOfDay(slots.morningDropoffAtSchool),
                            color: AppTheme.purple,
                            isLast: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Afternoon schedule ────────────────────────
                  _SectionLabel(label: AppStrings.t('afternoon_dropoff_s')),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: GlassCard(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        children: [
                          _TimelineItem(
                            icon: '🏫',
                            title: AppStrings.t('school_dismissal'),
                            subtitle: 'School / college / university pickup',
                            time: formatTimeOfDay(
                              slots.afternoonPickupFromSchool,
                            ),
                            color: AppTheme.purple,
                            isFirst: true,
                          ),
                          _TimelineItem(
                            icon: '✅',
                            title: AppStrings.t('qr_checkout'),
                            subtitle: 'Scan when boarding',
                            time: formatTimeOfDay(
                              slots.afternoonPickupFromSchool,
                            ),
                            color: AppTheme.success,
                          ),
                          _TimelineItem(
                            icon: '🚌',
                            title: AppStrings.t('bus_departs'),
                            subtitle: 'Route return journey',
                            time: formatTimeOfDay(
                              slots.afternoonPickupFromSchool,
                            ),
                            color: AppTheme.info,
                          ),
                          _TimelineItem(
                            icon: '🏠',
                            title: AppStrings.t('reach_stop'),
                            subtitle: 'Home drop-off',
                            time: formatTimeOfDay(slots.afternoonDropoffAtHome),
                            color: AppTheme.studentAmber,
                            isLast: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Weekly summary ────────────────────────────
                  _SectionLabel(label: AppStrings.t('this_week_summary')),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: GlassCard(
                      padding: const EdgeInsets.all(18),
                      child: ValueListenableBuilder<int>(
                        valueListenable:
                            StudentDataService.instance.completedRidesThisWeek,
                        builder: (_, ridesThisWeek, _) {
                          final ridesThisWeekLabel = ridesThisWeek.toString();
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _WeekStat(
                                icon: '🚌',
                                value: ridesThisWeekLabel,
                                label: AppStrings.t('rides_lbl'),
                                color: AppTheme.studentAmber,
                              ),
                              ValueListenableBuilder<int>(
                                valueListenable:
                                    StudentDataService.instance.onTimeRate,
                                builder: (_, rate, _) => _WeekStat(
                                  icon: '⏱️',
                                  value: '$rate%',
                                  label: AppStrings.t('on_time'),
                                  color: AppTheme.success,
                                ),
                              ),
                              // Same reasoning as `StudentDataService
                              // .safeRides`: a ride with no incident recorded
                              // against it is a safe ride, and until the
                              // Phase 3 safety layer writes incidents, that
                              // is every boarded ride — so this week's safe
                              // count equals this week's completed count.
                              _WeekStat(
                                icon: '🛡️',
                                value: ridesThisWeekLabel,
                                label: AppStrings.t('safe_rides'),
                                color: AppTheme.info,
                              ),
                            ],
                          );
                        },
                      ),
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

class _NoDriverState extends StatelessWidget {
  final Widget header;
  const _NoDriverState({required this.header});

  @override
  Widget build(BuildContext context) {
    return Column(
      // Was `.start` -- with no `width`/`Expanded`/`stretch` anywhere
      // below, a `Column`'s `.start` alignment lets each child (this
      // `Padding`+`GlassCard` included) shrink-wrap to its own natural
      // width instead of filling what the Column actually has available.
      // Here that meant the card sized itself to its one line of centered
      // text, then sat flush against the *left* margin (honoring `.start`)
      // while the *right* side was simply wherever the text happened to
      // end -- an uneven gap, not a layout bug in the card itself.
      // `.stretch` forces every child, including this one, to fill the
      // Column's full width; each child's own internal alignment (the
      // header's left-aligned title, the card's centered icon/text below)
      // is unaffected, since that's controlled by their own widgets, not
      // by this outer one.
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        const SizedBox(height: 16),
        Padding(
          // Matches the header's own `EdgeInsets.fromLTRB(20, ...)` margin
          // (`_buildHeader`) exactly -- was `16` here, 4px narrower than
          // the header on each side, so even a full-width card wouldn't
          // have lined up with the title above it.
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: GlassCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              // Explicit, not just relying on `Column`'s own `.center`
              // default, so it's clear this is deliberate: the icon and
              // text should stay centered no matter how wide the card
              // ends up being.
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text('🚌', style: TextStyle(fontSize: 32)),
                const SizedBox(height: 12),
                Text(
                  'Please select a driver to view the schedule.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.textSecondary, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Text(
        label,
        style: TextStyle(
          color: context.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _TimeOptionCard extends StatelessWidget {
  final String title, subtitle, time, icon;
  final Color color;
  final VoidCallback onTap;

  const _TimeOptionCard({
    required this.title,
    required this.subtitle,
    required this.time,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.cardBgElevated,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(icon, style: const TextStyle(fontSize: 20)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  time,
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Tap to change',
                  style: TextStyle(color: context.textTertiary, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final String icon, title, subtitle, time;
  final Color color;
  final bool isFirst, isLast;
  const _TimelineItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.color,
    this.isFirst = false,
    this.isLast = false,
  });
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Center(
                child: Text(icon, style: const TextStyle(fontSize: 14)),
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 28,
                margin: const EdgeInsets.symmetric(vertical: 2),
                color: color.withValues(alpha: 0.2),
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      time,
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(color: context.textTertiary, fontSize: 11),
                ),
                if (!isLast) const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _WeekStat extends StatelessWidget {
  final String icon, value, label;
  final Color color;
  const _WeekStat({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(icon, style: const TextStyle(fontSize: 22)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: context.textTertiary, fontSize: 11),
        ),
      ],
    );
  }
}
