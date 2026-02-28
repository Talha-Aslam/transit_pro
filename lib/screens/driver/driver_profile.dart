import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

class DriverProfile extends StatefulWidget {
  final void Function(int) onNavigate;
  final VoidCallback onLogout;

  const DriverProfile({super.key, required this.onNavigate, required this.onLogout});

  @override
  State<DriverProfile> createState() => _DriverProfileState();
}

class _DriverProfileState extends State<DriverProfile> {
  final double _rating = 4.8;
  bool _locationSharing = true;
  bool _parentAlerts    = true;
  bool _routeReminders  = true;
  bool _breakAlerts     = false;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 100),
      child: Column(
        children: [
          // ── Profile header ────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [AppTheme.driverCyan.withOpacity(0.25), Colors.transparent],
              ),
            ),
            child: Column(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 84, height: 84,
                      decoration: BoxDecoration(
                        color: Colors.blue.shade200.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(color: AppTheme.driverCyan.withOpacity(0.5), width: 3),
                        boxShadow: [
                          BoxShadow(color: AppTheme.driverCyan.withOpacity(0.3), blurRadius: 24, offset: const Offset(0, 8)),
                        ],
                      ),
                      child: const Center(child: Text('👨', style: TextStyle(fontSize: 44))),
                    ),
                    Positioned(
                      bottom: -4, right: -4,
                      child: Container(
                        width: 24, height: 24,
                        decoration: BoxDecoration(
                          gradient: AppTheme.driverGradient,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(child: Text('✏️', style: TextStyle(fontSize: 11))),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text('Mike Thompson',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 5),
                Text('mike@transport.com',
                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14)),
                const SizedBox(height: 12),
                // Star rating
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: List.generate(5, (i) => Text(
                        '⭐',
                        style: TextStyle(
                          fontSize: 16,
                          color: i < _rating.floor() ? Colors.white : Colors.white.withOpacity(0.3),
                        ),
                      )),
                    ),
                    const SizedBox(width: 8),
                    Text('$_rating', style: const TextStyle(color: AppTheme.warningLight, fontSize: 14, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 6),
                    Text('(128 ratings)', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.success.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6, height: 6,
                        decoration: const BoxDecoration(color: AppTheme.success, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      const Text('Active · On Route',
                          style: TextStyle(color: AppTheme.successLight, fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                // ── Driver info ───────────────────────────────────────────
                GlassCard(
                  gradient: LinearGradient(
                    colors: [AppTheme.driverCyan.withOpacity(0.1), AppTheme.driverTeal.withOpacity(0.05)],
                  ),
                  borderColor: AppTheme.driverCyan.withOpacity(0.2),
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('DRIVER INFORMATION',
                          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11,
                              fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                      const SizedBox(height: 14),
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 1.9,
                        children: const [
                          _InfoCard(icon: '🪪',  label: 'License No.',     value: 'DL-2024-8847'),
                          _InfoCard(icon: '📅',  label: 'Experience',       value: '8 Years'),
                          _InfoCard(icon: '🚌',  label: 'Bus Number',       value: 'Bus #42'),
                          _InfoCard(icon: '🗺️', label: 'Route',             value: 'Route A – East'),
                          _InfoCard(icon: '📞',  label: 'Mobile',           value: '+1 555-0200'),
                          _InfoCard(icon: '👥',  label: 'Total Students',   value: '22'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ── Bus info ──────────────────────────────────────────────
                GlassCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('BUS INFORMATION',
                          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11,
                              fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Container(
                            width: 56, height: 56,
                            decoration: BoxDecoration(
                              gradient: AppTheme.driverGradient,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: const Center(child: Text('🚌', style: TextStyle(fontSize: 28))),
                          ),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('School Bus #42',
                                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 3),
                              Text('2022 Ford Transit · Yellow',
                                  style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          _BusChip(label: 'Capacity',     value: '28 seats'),
                          const SizedBox(width: 8),
                          _BusChip(label: 'Fuel',         value: 'CNG'),
                          const SizedBox(width: 8),
                          _BusChip(label: 'Last Service', value: 'Feb 10'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ── Settings toggles ──────────────────────────────────────
                GlassCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('APP SETTINGS',
                          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11,
                              fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                      const SizedBox(height: 4),
                      _PrefRow(label: 'Share Location',       desc: 'Parents can see bus location',    value: _locationSharing, onChanged: (v) => setState(() => _locationSharing = v)),
                      _divider(),
                      _PrefRow(label: 'Parent Auto-Alerts',   desc: 'Send boarding notifications',     value: _parentAlerts, onChanged: (v) => setState(() => _parentAlerts = v)),
                      _divider(),
                      _PrefRow(label: 'Route Reminders',      desc: '10 min before each stop',         value: _routeReminders, onChanged: (v) => setState(() => _routeReminders = v)),
                      _divider(),
                      _PrefRow(label: 'Break Notifications',  desc: 'Alert for scheduled breaks',      value: _breakAlerts, onChanged: (v) => setState(() => _breakAlerts = v)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ── Menu items ────────────────────────────────────────────
                GlassCard(
                  child: Column(
                    children: const [
                      _MenuItem(icon: '📋', label: 'Trip History',       desc: '248 trips completed'),
                      _MenuItem(icon: '🏆', label: 'Performance Report', desc: '96% on-time rate'),
                      _MenuItem(icon: '📜', label: 'Documents & License', desc: 'All verified ✓'),
                      _MenuItem(icon: '🔐', label: 'Change Password'),
                      _MenuItem(icon: '📞', label: 'Emergency Contacts'),
                      _MenuItem(icon: '❓', label: 'Help & Support', isLast: true),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ── Logout ────────────────────────────────────────────────
                GestureDetector(
                  onTap: widget.onLogout,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.error.withOpacity(0.25)),
                    ),
                    child: const Center(
                      child: Text('🚪  Log Out',
                          style: TextStyle(color: AppTheme.errorLight, fontSize: 15, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('TransportKid v2.4.1 · © 2026',
                    style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Widget _divider() => Container(height: 1, color: Colors.white.withOpacity(0.06));

class _PrefRow extends StatelessWidget {
  final String label, desc;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _PrefRow({required this.label, required this.desc, required this.value, required this.onChanged});

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
                Text(label, style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 14)),
                const SizedBox(height: 2),
                Text(desc, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12)),
              ],
            ),
          ),
          AppSwitch(value: value, onChanged: onChanged, activeColor: AppTheme.driverCyan),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String icon, label, value;
  const _InfoCard({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 9, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _BusChip extends StatelessWidget {
  final String label, value;
  const _BusChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 9)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final String icon, label;
  final String? desc;
  final bool isLast;
  const _MenuItem({required this.icon, required this.label, this.desc, this.isLast = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        border: isLast ? null : Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: Row(
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(child: Text(icon, style: const TextStyle(fontSize: 18))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 14)),
                if (desc != null) ...[
                  const SizedBox(height: 2),
                  Text(desc!, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12)),
                ],
              ],
            ),
          ),
          Text('›', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 20)),
        ],
      ),
    );
  }
}
