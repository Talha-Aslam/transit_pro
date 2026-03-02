import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

class StudentAttendance extends StatefulWidget {
  const StudentAttendance({super.key});
  @override
  State<StudentAttendance> createState() => _StudentAttendanceState();
}

class _StudentAttendanceState extends State<StudentAttendance>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _toggleScan() {
    setState(() => _isScanning = !_isScanning);
    if (_isScanning) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _isScanning = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 100),
      child: Column(
        children: [
          // ── Header ────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'QR Pass',
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Show your pass for check-in & check-out',
                  style: TextStyle(color: context.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── QR Code Card ──────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: GlassCard(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.studentAmber.withOpacity(0.12),
                  AppTheme.studentOrange.withOpacity(0.06),
                ],
              ),
              borderColor: AppTheme.studentAmber.withOpacity(0.25),
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Student info
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: AppTheme.studentGradient,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Center(
                          child: Text('🎓', style: TextStyle(fontSize: 22)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Noorulain',
                              style: TextStyle(
                                color: context.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'ID: STU-2024-042',
                              style: TextStyle(
                                color: context.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      StatusBadge(label: 'Valid', color: AppTheme.success),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // QR code placeholder
                  AnimatedBuilder(
                    animation: _pulseCtrl,
                    builder: (ctx, child) {
                      final glow = _isScanning
                          ? 0.3 + 0.2 * math.sin(_pulseCtrl.value * math.pi * 2)
                          : 0.0;
                      return Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          color: context.textPrimary,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: _isScanning
                              ? [
                                  BoxShadow(
                                    color: AppTheme.studentAmber.withOpacity(
                                      glow,
                                    ),
                                    blurRadius: 30,
                                    spreadRadius: 4,
                                  ),
                                ]
                              : null,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: _QRPattern(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // Route & bus info
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: context.cardBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '🚌 Bus #42',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 14,
                          margin: const EdgeInsets.symmetric(horizontal: 12),
                          color: context.surfaceBorder,
                        ),
                        Text(
                          '📍 Route A',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Scan button
                  GestureDetector(
                    onTap: _toggleScan,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        gradient: _isScanning
                            ? LinearGradient(
                                colors: [
                                  AppTheme.success,
                                  AppTheme.success.withOpacity(0.7),
                                ],
                              )
                            : AppTheme.studentGradient,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color:
                                (_isScanning
                                        ? AppTheme.success
                                        : AppTheme.studentAmber)
                                    .withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          _isScanning ? '📡 Scanning...' : '📲 Ready to Scan',
                          style: TextStyle(
                            color: context.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── Today's Attendance ─────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(left: 4, bottom: 10),
                  child: Text(
                    "Today's Check-ins",
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _CheckinCard(
                  type: 'Morning Pickup',
                  time: '07:22 AM',
                  location: 'Pine Road Stop',
                  icon: '🌅',
                  color: AppTheme.studentAmber,
                  status: 'Checked In',
                ),
                const SizedBox(height: 10),
                _CheckinCard(
                  type: 'School Arrival',
                  time: '07:35 AM',
                  location: 'Lincoln Elementary',
                  icon: '🏫',
                  color: AppTheme.success,
                  status: 'Checked In',
                ),
                const SizedBox(height: 10),
                _CheckinCard(
                  type: 'Afternoon Pickup',
                  time: '--:--',
                  location: 'Lincoln Elementary',
                  icon: '🌤️',
                  color: Colors.white24,
                  status: 'Pending',
                ),
                const SizedBox(height: 10),
                _CheckinCard(
                  type: 'Home Drop-off',
                  time: '--:--',
                  location: 'Pine Road Stop',
                  icon: '🏠',
                  color: Colors.white24,
                  status: 'Pending',
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Monthly stats ─────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GlassCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Monthly Report',
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _Stat(
                        val: '42',
                        label: 'Total\nCheck-ins',
                        color: AppTheme.studentAmber,
                      ),
                      _Stat(
                        val: '98%',
                        label: 'Attendance\nRate',
                        color: AppTheme.success,
                      ),
                      _Stat(
                        val: '1',
                        label: 'Missed\nDays',
                        color: AppTheme.error,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── QR Pattern placeholder ──────────────────────────────────────────────

class _QRPattern extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _QRPainter(), size: const Size(168, 168));
  }
}

class _QRPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black;
    final r = math.Random(42);
    final cellSize = size.width / 21;

    // Corner patterns
    _drawFinderPattern(canvas, paint, 0, 0, cellSize);
    _drawFinderPattern(canvas, paint, 14 * cellSize, 0, cellSize);
    _drawFinderPattern(canvas, paint, 0, 14 * cellSize, cellSize);

    // Random data modules
    for (int x = 0; x < 21; x++) {
      for (int y = 0; y < 21; y++) {
        if (_isInFinder(x, y)) continue;
        if (r.nextBool()) {
          canvas.drawRect(
            Rect.fromLTWH(x * cellSize, y * cellSize, cellSize, cellSize),
            paint,
          );
        }
      }
    }
  }

  void _drawFinderPattern(
    Canvas canvas,
    Paint paint,
    double x,
    double y,
    double cell,
  ) {
    // Outer
    canvas.drawRect(Rect.fromLTWH(x, y, 7 * cell, 7 * cell), paint);
    // Inner white
    final white = Paint()..color = Colors.white;
    canvas.drawRect(
      Rect.fromLTWH(x + cell, y + cell, 5 * cell, 5 * cell),
      white,
    );
    // Center
    canvas.drawRect(
      Rect.fromLTWH(x + 2 * cell, y + 2 * cell, 3 * cell, 3 * cell),
      paint,
    );
  }

  bool _isInFinder(int x, int y) {
    if (x < 8 && y < 8) return true;
    if (x >= 13 && y < 8) return true;
    if (x < 8 && y >= 13) return true;
    return false;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Widgets ─────────────────────────────────────────────────────────────

class _CheckinCard extends StatelessWidget {
  final String type, time, location, icon, status;
  final Color color;
  const _CheckinCard({
    required this.type,
    required this.time,
    required this.location,
    required this.icon,
    required this.color,
    required this.status,
  });
  @override
  Widget build(BuildContext context) {
    final done = status == 'Checked In';
    return GlassCard(
      gradient: done
          ? LinearGradient(
              colors: [color.withOpacity(0.08), color.withOpacity(0.02)],
            )
          : null,
      borderColor: done ? color.withOpacity(0.15) : null,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
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
                  type,
                  style: TextStyle(
                    color: done ? Colors.white : context.textTertiary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  location,
                  style: TextStyle(
                    color: Colors.white.withOpacity(done ? 0.4 : 0.25),
                    fontSize: 11,
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
                  color: done ? Colors.white : context.textTertiary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              StatusBadge(
                label: status,
                color: done ? AppTheme.success : Colors.white24,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String val, label;
  final Color color;
  const _Stat({required this.val, required this.label, required this.color});
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          val,
          style: TextStyle(
            color: color,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(color: context.textTertiary, fontSize: 11),
        ),
      ],
    );
  }
}
