import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

class ParentDashboard extends StatelessWidget {
  final void Function(int) onNavigate;

  const ParentDashboard({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good Morning' : hour < 17 ? 'Good Afternoon' : 'Good Evening';

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 100),
      child: Column(
        children: [
          // ── Header ────────────────────────────────────────────────────────
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$greeting 👋',
                          style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 13)),
                      const SizedBox(height: 4),
                      const Text('Sarah Johnson',
                          style: TextStyle(
                              color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                    ],
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
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white.withOpacity(0.12)),
                        ),
                        child: const Center(child: Text('🔔', style: TextStyle(fontSize: 18))),
                      ),
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
                          child: const Center(
                            child: Text('3', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Avatar
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.parentPurple.withOpacity(0.5), width: 2),
                  ),
                  child: const Center(child: Text('👩', style: TextStyle(fontSize: 24))),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                // ── Child status banner ───────────────────────────────────
                GlassCard(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.success.withOpacity(0.15),
                      AppTheme.success.withOpacity(0.05),
                    ],
                  ),
                  borderColor: AppTheme.success.withOpacity(0.25),
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.amber.shade200.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.success.withOpacity(0.4), width: 2),
                        ),
                        child: const Center(child: Text('👧', style: TextStyle(fontSize: 28))),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text('Emma Johnson',
                                    style: TextStyle(
                                        color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                                const SizedBox(width: 8),
                                StatusBadge(
                                  label: '● On the Bus',
                                  color: AppTheme.success,
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text('Grade 5 · Lincoln Elementary',
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.55), fontSize: 12)),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => onNavigate(1),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: AppTheme.success.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.success.withOpacity(0.3)),
                          ),
                          child: const Center(child: Text('📍', style: TextStyle(fontSize: 18))),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ── Live ETA card ─────────────────────────────────────────
                GlassCard(
                  onTap: () => onNavigate(1),
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.parentPurple.withOpacity(0.2),
                      AppTheme.parentIndigo.withOpacity(0.08),
                    ],
                  ),
                  borderColor: AppTheme.parentPurple.withOpacity(0.25),
                  padding: const EdgeInsets.all(18),
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
                              color: AppTheme.parentPurple.withOpacity(0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Center(child: Text('🚌', style: TextStyle(fontSize: 28))),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('BUS #42 · ROUTE A',
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.55),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5)),
                            const SizedBox(height: 4),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                ShaderMask(
                                  shaderCallback: (b) => const LinearGradient(
                                    colors: [Color(0xFFA78BFA), Color(0xFF60A5FA)],
                                  ).createShader(b),
                                  child: const Text('8 min',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 30,
                                          fontWeight: FontWeight.w800)),
                                ),
                                const SizedBox(width: 6),
                                Text('to school',
                                    style: TextStyle(
                                        color: Colors.white.withOpacity(0.5), fontSize: 13)),
                              ],
                            ),
                            Text('📍 Currently at Pine Road Stop',
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.4), fontSize: 12)),
                          ],
                        ),
                      ),
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppTheme.parentAccent.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.parentAccent.withOpacity(0.3)),
                        ),
                        child: const Center(
                          child: Text('→', style: TextStyle(color: Colors.white, fontSize: 18)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ── Stats grid ────────────────────────────────────────────
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 2.2,
                  children: [
                    _StatCard(icon: '🚌', label: 'Total Trips', value: '142', color: AppTheme.purple),
                    _StatCard(icon: '⏱️', label: 'On-Time', value: '96%', color: AppTheme.success),
                    _StatCard(icon: '📅', label: 'This Week', value: '5', color: AppTheme.info),
                    _StatCard(icon: '🛡️', label: 'Safe Rides', value: '142', color: AppTheme.warning),
                  ],
                ),
                const SizedBox(height: 12),

                // ── Today's schedule ──────────────────────────────────────
                GlassCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Today's Schedule",
                              style: TextStyle(
                                  color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                          GestureDetector(
                            onTap: () => onNavigate(2),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.parentAccent.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppTheme.parentAccent.withOpacity(0.3)),
                              ),
                              child: Text('View All',
                                  style: TextStyle(color: AppTheme.parentAccent, fontSize: 12)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          _ScheduleChip(icon: '🌅', label: 'Pickup', time: '07:15 AM', status: 'Done', color: AppTheme.success),
                          const SizedBox(width: 8),
                          _ScheduleChip(icon: '🏫', label: 'At School', time: '07:45 AM', status: 'Done', color: AppTheme.success),
                          const SizedBox(width: 8),
                          _ScheduleChip(icon: '🌇', label: 'Drop Off', time: '03:30 PM', status: 'Pending', color: AppTheme.warning),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ── Recent alerts ─────────────────────────────────────────
                GlassCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Recent Alerts',
                              style: TextStyle(
                                  color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                          GestureDetector(
                            onTap: () => onNavigate(3),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.parentAccent.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppTheme.parentAccent.withOpacity(0.3)),
                              ),
                              child: Text('View All',
                                  style: TextStyle(color: AppTheme.parentAccent, fontSize: 12)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...[
                        ('✅', 'Emma boarded Bus #42 at Oak Street', '07:18 AM', AppTheme.success),
                        ('🟢', 'Bus #42 is running 5 min ahead', '07:10 AM', AppTheme.success),
                        ('🔔', 'Bus approaching your stop in 8 min', '06:55 AM', AppTheme.warning),
                      ].map((a) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _AlertRow(icon: a.$1, msg: a.$2, time: a.$3, color: a.$4),
                      )),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String icon, label, value;
  final Color color;

  const _StatCard({required this.icon, required this.label, required this.value, required this.color});

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
            child: Center(child: Text(icon, style: const TextStyle(fontSize: 17))),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(value,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                Text(label,
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.45), fontSize: 10)),
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
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 5),
            Text(label,
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10)),
            const SizedBox(height: 3),
            Text(time,
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
            const SizedBox(height: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Text(status, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w600)),
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

  const _AlertRow({required this.icon, required this.msg, required this.time, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
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
            child: Center(child: Text(icon, style: const TextStyle(fontSize: 16))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(msg,
                    style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(time,
                    style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
