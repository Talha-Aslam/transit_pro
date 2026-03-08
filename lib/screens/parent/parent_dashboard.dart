import 'dart:io';
import 'package:flutter/material.dart';
import '../../app/parent_data_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

class ParentDashboard extends StatelessWidget {
  final void Function(int) onNavigate;
  final int unreadCount;

  const ParentDashboard({
    super.key,
    required this.onNavigate,
    this.unreadCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good Morning'
        : hour < 17
        ? 'Good Afternoon'
        : 'Good Evening';

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
                          AppTheme.parentPurple.withOpacity(0.2),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: ValueListenableBuilder(
                            valueListenable: svc.parentInfo,
                            builder: (_, info, __) => Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$greeting‘‹',
                                  style: TextStyle(
                                    color: context.textSecondary,
                                    fontSize: 13,
                                  ),
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
                          onTap: () => onNavigate(3),
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
                                child: unreadCount > 0
                                    ? Image.asset(
                                        'assets/images/notification_bell.gif',
                                        width: 36,
                                        height: 36,
                                        filterQuality: FilterQuality.high,
                                      )
                                    : Center(
                                        child: Image.asset(
                                          'assets/images/notification_bell_off.png',
                                          width: 28,
                                          height: 28,
                                          fit: BoxFit.contain,
                                          filterQuality: FilterQuality.high,
                                        ),
                                      ),
                              ),
                              if (unreadCount > 0)
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
                                        '$unreadCount',
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
                              separatorBuilder: (_, __) =>
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
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.success.withOpacity(0.15),
                              AppTheme.success.withOpacity(0.05),
                            ],
                          ),
                          borderColor: AppTheme.success.withOpacity(0.25),
                          padding: const EdgeInsets.all(18),
                          child: child == null
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    child: Text(
                                      'No children added yet',
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
                                      builder: (_, imgs, __) {
                                        final file = safeIdx < imgs.length
                                            ? imgs[safeIdx]
                                            : null;
                                        return Container(
                                          width: 62,
                                          height: 62,
                                          decoration: BoxDecoration(
                                            color: AppTheme.parentPurple
                                                .withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            border: Border.all(
                                              color: AppTheme.success
                                                  .withOpacity(0.4),
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
                                            label: 'â— On the Bus',
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
                          onTap: () => onNavigate(1),
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.parentPurple.withOpacity(0.2),
                              AppTheme.parentIndigo.withOpacity(0.08),
                            ],
                          ),
                          borderColor: AppTheme.parentPurple.withOpacity(0.25),
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
                                      color: AppTheme.parentPurple.withOpacity(
                                        0.4,
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
                                          : '${child.busNumber.toUpperCase()} Â· ${child.route.toUpperCase()}',
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
                                          child: Text(
                                            '8 min',
                                            style: TextStyle(
                                              color: context.textPrimary,
                                              fontSize: 30,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'to school',
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
                                          : 'ðŸ“ Currently at ${child.stop}',
                                      style: TextStyle(
                                        color: context.textTertiary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: AppTheme.parentAccent.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppTheme.parentAccent.withOpacity(
                                      0.3,
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
                        const SizedBox(height: 30),

                        // â”€â”€ Today's schedule â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                        GlassCard(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "Today's Schedule",
                                    style: TextStyle(
                                      color: context.textPrimary,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => onNavigate(2),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.parentAccent
                                            .withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: AppTheme.parentAccent
                                              .withOpacity(0.3),
                                        ),
                                      ),
                                      child: Text(
                                        'View All',
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
                                        'assets/images/waiting_for_bus_transparent.png',
                                    label: 'Pickup',
                                    time: '07:15 AM',
                                    status: 'Done',
                                    color: AppTheme.success,
                                  ),
                                  const SizedBox(width: 8),
                                  _ScheduleChip(
                                    icon: 'assets/images/at_school.png',
                                    label: 'At School',
                                    time: '07:45 AM',
                                    status: 'Done',
                                    color: AppTheme.success,
                                  ),
                                  const SizedBox(width: 8),
                                  _ScheduleChip(
                                    icon:
                                        'assets/images/drop_off_transparent.png',
                                    label: 'Drop Off',
                                    time: '03:30 PM',
                                    status: 'Pending',
                                    color: AppTheme.warning,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // â”€â”€ Stats grid â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                        GridView.count(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 2.2,
                          children: [
                            _StatCard(
                              icon: 'assets/images/total_trips.png',
                              label: 'Total Trips',
                              value: '142',
                              color: AppTheme.purple,
                            ),
                            _StatCard(
                              icon: 'assets/images/on_time.png',
                              label: 'On-Time',
                              value: '96%',
                              color: AppTheme.success,
                            ),
                            _StatCard(
                              icon: 'assets/images/calendar.png',
                              label: 'This Week',
                              value: '5',
                              color: AppTheme.info,
                            ),
                            _StatCard(
                              icon: 'assets/images/safety.png',
                              label: 'Safe Rides',
                              value: '142',
                              color: AppTheme.warning,
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // â”€â”€ Recent alerts â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                        GlassCard(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Recent Alerts',
                                    style: TextStyle(
                                      color: context.textPrimary,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => onNavigate(3),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.parentAccent
                                            .withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: AppTheme.parentAccent
                                              .withOpacity(0.3),
                                        ),
                                      ),
                                      child: Text(
                                        'View All',
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
                              ...[
                                (
                                  'assets/images/check.png',
                                  child == null
                                      ? 'No child selected'
                                      : '${child.name.split(' ').first} boarded ${child.busNumber} at ${child.stop}',
                                  '07:18 AM',
                                  AppTheme.success,
                                ),
                                (
                                  'assets/images/route_in_progress.png',
                                  child == null
                                      ? ''
                                      : '${child.busNumber} is running 5 min ahead',
                                  '07:10 AM',
                                  AppTheme.success,
                                ),
                                (
                                  'assets/images/alert.png',
                                  'Bus approaching your stop in 8 min',
                                  '06:55 AM',
                                  AppTheme.warning,
                                ),
                              ].map(
                                (a) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: _AlertRow(
                                    icon: a.$1,
                                    msg: a.$2,
                                    time: a.$3,
                                    color: a.$4,
                                  ),
                                ),
                              ),
                            ],
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
      },
    );
  }
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withOpacity(0.13),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.27)),
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
          color: Colors.white.withOpacity(0.04),
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
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: color.withOpacity(0.3)),
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
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.cardBg),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.25)),
            ),
            child: Center(
              child: Image.asset(
                icon,
                width: 22,
                height: 22,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
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
