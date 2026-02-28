import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

class ParentProfile extends StatefulWidget {
  final void Function(int) onNavigate;
  final VoidCallback onLogout;

  const ParentProfile({super.key, required this.onNavigate, required this.onLogout});

  @override
  State<ParentProfile> createState() => _ParentProfileState();
}

class _ParentProfileState extends State<ParentProfile> {
  bool _boardingAlert = true;
  bool _arrivalAlert  = true;
  bool _delayAlert    = true;
  bool _smsNotif      = false;
  bool _emailNotif    = true;

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
                colors: [AppTheme.parentPurple.withOpacity(0.25), Colors.transparent],
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
                        color: Colors.amber.shade200.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(color: AppTheme.parentPurple.withOpacity(0.5), width: 3),
                        boxShadow: [
                          BoxShadow(color: AppTheme.parentPurple.withOpacity(0.3), blurRadius: 24, offset: const Offset(0, 8)),
                        ],
                      ),
                      child: const Center(child: Text('👩', style: TextStyle(fontSize: 44))),
                    ),
                    Positioned(
                      bottom: -4, right: -4,
                      child: Container(
                        width: 24, height: 24,
                        decoration: BoxDecoration(
                          gradient: AppTheme.parentGradient,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(child: Text('✏️', style: TextStyle(fontSize: 11))),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text('Sarah Johnson',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 5),
                Text('sarah@example.com',
                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14)),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.parentPurple.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.parentPurple.withOpacity(0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('⭐', style: TextStyle(fontSize: 10)),
                      SizedBox(width: 5),
                      Text('Premium Member',
                          style: TextStyle(color: AppTheme.parentAccent, fontSize: 12, fontWeight: FontWeight.w600)),
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
                // ── Child info ───────────────────────────────────────────
                GlassCard(
                  gradient: LinearGradient(
                    colors: [AppTheme.parentPurple.withOpacity(0.1), AppTheme.info.withOpacity(0.05)],
                  ),
                  borderColor: AppTheme.parentPurple.withOpacity(0.2),
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('CHILD INFORMATION',
                          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11,
                              fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Container(
                            width: 48, height: 48,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFD97706)]),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Center(child: Text('👧', style: TextStyle(fontSize: 24))),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Emma Johnson',
                                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 3),
                              Text('Grade 5 · Lincoln Elementary School',
                                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 2.4,
                        children: const [
                          _MiniCard(label: 'Bus Number', value: 'Bus #42'),
                          _MiniCard(label: 'Route',      value: 'Route A'),
                          _MiniCard(label: 'Stop',       value: 'Oak Street'),
                          _MiniCard(label: 'Driver',     value: 'Mike T.'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ── Notification preferences ─────────────────────────────
                GlassCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('NOTIFICATION PREFERENCES',
                          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11,
                              fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                      const SizedBox(height: 4),
                      _PrefRow(label: 'Boarding Alerts',        desc: 'When Emma boards/exits',  value: _boardingAlert, onChanged: (v) => setState(() => _boardingAlert = v)),
                      _divider(),
                      _PrefRow(label: 'Arrival Notifications',  desc: 'School & home arrivals',  value: _arrivalAlert, onChanged: (v) => setState(() => _arrivalAlert = v)),
                      _divider(),
                      _PrefRow(label: 'Delay Alerts',           desc: 'When bus is late',        value: _delayAlert, onChanged: (v) => setState(() => _delayAlert = v)),
                      _divider(),
                      _PrefRow(label: 'SMS Notifications',      desc: 'Text message alerts',     value: _smsNotif, onChanged: (v) => setState(() => _smsNotif = v)),
                      _divider(),
                      _PrefRow(label: 'Email Notifications',    desc: 'Daily summary email',     value: _emailNotif, onChanged: (v) => setState(() => _emailNotif = v)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ── Menu items ───────────────────────────────────────────
                GlassCard(
                  child: Column(
                    children: [
                      _MenuItem(icon: '📋', label: 'Trip History',       desc: '142 completed trips'),
                      _MenuItem(icon: '💳', label: 'Subscription',        desc: 'Premium Plan · Active'),
                      _MenuItem(icon: '📞', label: 'Emergency Contacts',  desc: '2 contacts added'),
                      _MenuItem(icon: '🔐', label: 'Change Password'),
                      _MenuItem(icon: '🌐', label: 'Language',            desc: 'English'),
                      _MenuItem(icon: '❓', label: 'Help & Support'),
                      _MenuItem(icon: '⭐', label: 'Rate the App',        isLast: true),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ── Logout ───────────────────────────────────────────────
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

Widget _divider() => Container(
  height: 1, color: Colors.white.withOpacity(0.06),
  margin: const EdgeInsets.symmetric(vertical: 0),
);

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
                Text(label,
                    style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 14)),
                const SizedBox(height: 2),
                Text(desc, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12)),
              ],
            ),
          ),
          AppSwitch(value: value, onChanged: onChanged, activeColor: AppTheme.parentPurple),
        ],
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
                Text(label,
                    style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 14)),
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

class _MiniCard extends StatelessWidget {
  final String label, value;
  const _MiniCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 9, fontWeight: FontWeight.w600)),
          const SizedBox(height: 3),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
