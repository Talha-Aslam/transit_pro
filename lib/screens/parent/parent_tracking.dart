import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

class ParentTracking extends StatefulWidget {
  final VoidCallback onBack;
  const ParentTracking({super.key, required this.onBack});

  @override
  State<ParentTracking> createState() => _ParentTrackingState();
}

class _ParentTrackingState extends State<ParentTracking>
    with SingleTickerProviderStateMixin {
  late AnimationController _busController;
  double _eta = 8.0;

  @override
  void initState() {
    super.initState();
    _busController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
    _busController.addListener(() {
      if (mounted) {
        setState(() {
          _eta = 8.0 - (_busController.value * 7.0);
          if (_eta < 1.0) _eta = 8.0;
        });
      }
    });
  }

  @override
  void dispose() {
    _busController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final etaInt = _eta.round().clamp(1, 8);
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 100),
      child: Column(
        children: [
          // ── Header ───────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
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
                GestureDetector(
                  onTap: widget.onBack,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.12)),
                    ),
                    child: const Center(
                      child: Text(
                        '←',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Live Tracking',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Bus #42 · Route A',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedBuilder(
                  animation: _busController,
                  builder: (_, __) => Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppTheme.success,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.success.withOpacity(0.6),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'LIVE',
                        style: TextStyle(
                          color: AppTheme.successLight,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
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
                // ── ETA Banner ───────────────────────────────────────────
                GlassCard(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.parentPurple.withOpacity(0.2),
                      AppTheme.info.withOpacity(0.1),
                    ],
                  ),
                  borderColor: AppTheme.parentPurple.withOpacity(0.3),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ESTIMATED ARRIVAL',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.55),
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                '$etaInt',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'min',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.5),
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'ARRIVAL TIME',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.55),
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            '07:45 AM',
                            style: TextStyle(
                              color: AppTheme.parentAccent,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ── Route Map ────────────────────────────────────────────
                GlassCard(
                  backgroundColor: const Color(0xCC0A0F28),
                  borderRadius: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Route Map',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(color: Color(0x10FFFFFF), height: 1),
                      SizedBox(
                        width: double.infinity,
                        height: 200,
                        child: AnimatedBuilder(
                          animation: _busController,
                          builder: (_, __) => CustomPaint(
                            painter: _RouteMapPainter(_busController.value),
                            size: const Size(double.infinity, 200),
                          ),
                        ),
                      ),
                      const Divider(color: Color(0x10FFFFFF), height: 1),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            _LegendDot(
                              color: AppTheme.success,
                              label: 'Completed',
                            ),
                            const SizedBox(width: 16),
                            _LegendDot(
                              color: AppTheme.purple,
                              label: 'Current',
                            ),
                            const SizedBox(width: 16),
                            _LegendDot(color: AppTheme.info, label: 'Upcoming'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ── Route Stops ──────────────────────────────────────────
                GlassCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Route Stops',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 14),
                      ..._stops.asMap().entries.map(
                        (e) => _StopRow(
                          stop: e.value,
                          isLast: e.key == _stops.length - 1,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ── Bus Info ─────────────────────────────────────────────
                GlassCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Bus Information',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 14),
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 1.5,
                        children: const [
                          _InfoCard(
                            icon: '👨‍✈️',
                            label: 'Driver',
                            value: 'Mike Thompson',
                          ),
                          _InfoCard(
                            icon: '🚌',
                            label: 'Bus Number',
                            value: '#42',
                          ),
                          _InfoCard(
                            icon: '⚡',
                            label: 'Speed',
                            value: '35 km/h',
                          ),
                          _InfoCard(
                            icon: '👦',
                            label: 'Students',
                            value: '22 onboard',
                          ),
                        ],
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
  }
}

const _stops = [
  _Stop(name: 'Oak Street', time: '07:15', status: 'done'),
  _Stop(name: 'Maple Avenue', time: '07:22', status: 'done'),
  _Stop(name: 'Pine Road', time: '07:30', status: 'current'),
  _Stop(name: 'Cedar Blvd', time: '07:37', status: 'upcoming'),
  _Stop(name: 'Lincoln Elementary', time: '07:45', status: 'school'),
];

class _Stop {
  final String name, time, status;
  const _Stop({required this.name, required this.time, required this.status});
}

class _StopRow extends StatelessWidget {
  final _Stop stop;
  final bool isLast;
  const _StopRow({required this.stop, required this.isLast});

  Color get _color {
    switch (stop.status) {
      case 'done':
        return AppTheme.success;
      case 'current':
        return AppTheme.purple;
      case 'upcoming':
        return AppTheme.info;
      default:
        return AppTheme.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 30,
          child: Column(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: _color.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: _color, width: 2),
                  boxShadow: stop.status == 'current'
                      ? [
                          BoxShadow(
                            color: _color.withOpacity(0.4),
                            blurRadius: 10,
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: stop.status == 'done'
                      ? Text(
                          '✓',
                          style: TextStyle(
                            color: _color,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      : stop.status == 'school'
                      ? const Text('🏫', style: TextStyle(fontSize: 12))
                      : Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _color,
                            shape: BoxShape.circle,
                          ),
                        ),
                ),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 28,
                  margin: const EdgeInsets.symmetric(vertical: 2),
                  color: stop.status == 'done'
                      ? AppTheme.success.withOpacity(0.4)
                      : Colors.white.withOpacity(0.08),
                ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      stop.name,
                      style: TextStyle(
                        color: stop.status == 'current'
                            ? Colors.white
                            : Colors.white.withOpacity(0.75),
                        fontSize: 14,
                        fontWeight: stop.status == 'current'
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                    if (stop.status == 'current') ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.purple.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: AppTheme.purple.withOpacity(0.4),
                          ),
                        ),
                        child: const Text(
                          'NOW',
                          style: TextStyle(
                            color: AppTheme.parentAccent,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  stop.time,
                  style: TextStyle(
                    color: stop.status == 'done'
                        ? AppTheme.successLight
                        : stop.status == 'current'
                        ? AppTheme.parentAccent
                        : Colors.white.withOpacity(0.4),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
        ),
      ],
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.45),
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Custom Painter ─────────────────────────────────────────────────────────────
class _RouteMapPainter extends CustomPainter {
  final double progress;
  _RouteMapPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / 340;
    final scaleY = size.height / 200;

    Offset s(double x, double y) => Offset(x * scaleX, y * scaleY);

    // Grid
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..strokeWidth = 1;
    for (final y in [40.0, 80.0, 120.0, 160.0]) {
      canvas.drawLine(s(0, y), s(340, y), gridPaint);
    }
    for (final x in [60.0, 120.0, 180.0, 240.0, 300.0]) {
      canvas.drawLine(s(x, 0), s(x, 200), gridPaint);
    }

    // Roads
    final roadPaint = Paint()
      ..color = Colors.white.withOpacity(0.10)
      ..strokeWidth = 8 * scaleX
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(s(30, 148), s(310, 148), roadPaint);
    canvas.drawLine(s(100, 20), s(100, 160), roadPaint);
    canvas.drawLine(s(30, 78), s(310, 78), roadPaint);

    // Dashed route
    final dashPaint = Paint()
      ..color = AppTheme.purple.withOpacity(0.45)
      ..strokeWidth = 3 * scaleX
      ..strokeCap = StrokeCap.round;
    _drawDashedPolyline(canvas, [
      s(42, 148),
      s(100, 148),
      s(100, 78),
      s(210, 78),
      s(290, 78),
    ], dashPaint);

    // Completed portion
    final donePaint = Paint()
      ..color = AppTheme.success
      ..strokeWidth = 3 * scaleX
      ..strokeCap = StrokeCap.round;
    final seg1End = 0.35;
    if (progress < seg1End) {
      final t = progress / seg1End;
      canvas.drawLine(s(42, 148), s(100, 148), donePaint);
      canvas.drawLine(s(100, 148), s(100, 148 - t * 70), donePaint);
    } else {
      canvas.drawLine(s(42, 148), s(100, 148), donePaint);
      canvas.drawLine(s(100, 148), s(100, 78), donePaint);
      final t2 = (progress - seg1End) / (1.0 - seg1End);
      canvas.drawLine(s(100, 78), s(100 + t2 * 110, 78), donePaint);
    }

    // Stops
    final stopDefs = [
      (42.0, 148.0, AppTheme.success),
      (100.0, 148.0, AppTheme.success),
      (100.0, 78.0, AppTheme.purple),
      (210.0, 78.0, AppTheme.info),
      (290.0, 78.0, AppTheme.warning),
    ];
    for (final stop in stopDefs) {
      final center = s(stop.$1, stop.$2);
      final color = stop.$3;
      canvas.drawCircle(
        center,
        10 * scaleX,
        Paint()..color = color.withOpacity(0.2),
      );
      canvas.drawCircle(
        center,
        10 * scaleX,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      canvas.drawCircle(center, 4 * scaleX, Paint()..color = color);
    }

    // Bus position
    double busX, busY;
    if (progress < seg1End) {
      final t = progress / seg1End;
      busX = 100;
      busY = 148 - t * 70;
    } else {
      final t = (progress - seg1End) / (1.0 - seg1End);
      busX = 100 + t * 110;
      busY = 78;
    }
    final busCenter = s(busX, busY);
    final busRect = Rect.fromCenter(
      center: busCenter,
      width: 28 * scaleX,
      height: 28 * scaleY,
    );
    final rrect = RRect.fromRectAndRadius(busRect, Radius.circular(8 * scaleX));
    canvas.drawRRect(rrect, Paint()..color = AppTheme.purple.withOpacity(0.9));
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    final tp = TextPainter(
      text: const TextSpan(text: '🚌', style: TextStyle(fontSize: 14)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, busCenter - Offset(tp.width / 2, tp.height / 2));
  }

  void _drawDashedPolyline(Canvas canvas, List<Offset> points, Paint paint) {
    for (int i = 0; i < points.length - 1; i++) {
      _drawDashedLine(canvas, points[i], points[i + 1], paint);
    }
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dashLen = 6.0;
    const gapLen = 4.0;
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final dist = sqrt(dx * dx + dy * dy);
    final stepX = dx / dist;
    final stepY = dy / dist;
    double drawn = 0;
    bool drawing = true;
    double x = start.dx, y = start.dy;
    while (drawn < dist) {
      final step = drawing ? dashLen : gapLen;
      final remaining = dist - drawn;
      final len = min(step, remaining);
      final nx = x + stepX * len;
      final ny = y + stepY * len;
      if (drawing) canvas.drawLine(Offset(x, y), Offset(nx, ny), paint);
      x = nx;
      y = ny;
      drawn += len;
      drawing = !drawing;
    }
  }

  @override
  bool shouldRepaint(_RouteMapPainter old) => old.progress != progress;
}
