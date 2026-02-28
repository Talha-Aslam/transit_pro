import 'dart:math';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

class DriverRoute extends StatefulWidget {
  final VoidCallback onBack;
  const DriverRoute({super.key, required this.onBack});

  @override
  State<DriverRoute> createState() => _DriverRouteState();
}

class _DriverRouteState extends State<DriverRoute>
    with SingleTickerProviderStateMixin {
  late AnimationController _busController;
  int _speed = 35;
  final _random = Random();

  @override
  void initState() {
    super.initState();
    _busController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
    _busController.addListener(() {
      if (mounted && (_busController.value * 100).round() % 5 == 0) {
        setState(() => _speed = 30 + _random.nextInt(15));
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
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 100),
      child: Column(
        children: [
          // ── Header ───────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [AppTheme.driverCyan.withOpacity(0.2), Colors.transparent],
              ),
            ),
            child: Row(
              children: [
                GestureDetector(onTap: widget.onBack, child: _backBtn()),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Route Navigator',
                          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                      Text('Route A · Morning Run',
                          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13)),
                    ],
                  ),
                ),
                Row(
                  children: [
                    AnimatedBuilder(
                      animation: _busController,
                      builder: (_, __) => Container(
                        width: 8, height: 8,
                        decoration: BoxDecoration(
                          color: AppTheme.success,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: AppTheme.success.withOpacity(0.6), blurRadius: 8)],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text('LIVE',
                        style: TextStyle(color: AppTheme.successLight, fontSize: 12, fontWeight: FontWeight.w700)),
                  ],
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                // ── Map ──────────────────────────────────────────────────
                GlassCard(
                  backgroundColor: const Color(0xCC05081E),
                  borderRadius: 20,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Live Route Map',
                                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                            Row(
                              children: [
                                const Text('⚡ ', style: TextStyle(fontSize: 13)),
                                AnimatedBuilder(
                                  animation: _busController,
                                  builder: (_, __) => Text(
                                    '$_speed km/h',
                                    style: const TextStyle(
                                        color: AppTheme.driverAccent, fontSize: 13, fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Divider(color: Color(0x10FFFFFF), height: 1),
                      SizedBox(
                        width: double.infinity,
                        height: 210,
                        child: AnimatedBuilder(
                          animation: _busController,
                          builder: (_, __) => CustomPaint(
                            painter: _DriverRouteMapPainter(_busController.value),
                            size: const Size(double.infinity, 210),
                          ),
                        ),
                      ),
                      const Divider(color: Color(0x10FFFFFF), height: 1),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Row(
                          children: [
                            _LegendDot(color: AppTheme.success,  label: 'Completed'),
                            const SizedBox(width: 14),
                            _LegendDot(color: AppTheme.purple,   label: 'Current'),
                            const SizedBox(width: 14),
                            _LegendDot(color: AppTheme.info,     label: 'Next'),
                            const SizedBox(width: 14),
                            _LegendDot(color: AppTheme.warning,  label: 'School'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ── Live stats bar ────────────────────────────────────────
                Row(
                  children: [
                    _LiveStatCard(icon: '⏱️', label: 'ETA School',    value: '15 min'),
                    const SizedBox(width: 10),
                    _LiveStatCard(icon: '📏', label: 'Distance Left', value: '4.2 km'),
                    const SizedBox(width: 10),
                    _LiveStatCard(icon: '⚡', label: 'Avg Speed',      value: '35 km/h'),
                  ],
                ),
                const SizedBox(height: 12),

                // ── Route stops ───────────────────────────────────────────
                GlassCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Route Stops',
                          style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 16),
                      ..._routeStops.asMap().entries.map((e) => _StopRow(
                            stop: e.value,
                            isLast: e.key == _routeStops.length - 1,
                          )),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ── Action buttons ────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          gradient: AppTheme.driverGradient,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Center(
                          child: Text('✅  Mark Stop Done',
                              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: AppTheme.warning.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.warning.withOpacity(0.3)),
                        ),
                        child: const Center(
                          child: Text('⚠️  Report Issue',
                              style: TextStyle(color: AppTheme.warningLight, fontSize: 14, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveStatCard extends StatelessWidget {
  final String icon, label, value;
  const _LiveStatCard({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
            Text(label, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 9)),
          ],
        ),
      ),
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
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10)),
      ],
    );
  }
}

class _StopData {
  final String name, time, note, status, icon;
  final int students;
  const _StopData({required this.name, required this.time, required this.note,
      required this.status, required this.icon, required this.students});
}

const _routeStops = [
  _StopData(name: 'Bus Depot',          time: '06:55', students: 0, status: 'done',        icon: '🚌', note: 'Departure point'),
  _StopData(name: 'Oak Street',         time: '07:15', students: 3, status: 'done',        icon: '📍', note: '3 students picked up'),
  _StopData(name: 'Maple Avenue',       time: '07:22', students: 3, status: 'done',        icon: '📍', note: '3 students picked up'),
  _StopData(name: 'Pine Road',          time: '07:30', students: 2, status: 'current',     icon: '📍', note: 'Just completed'),
  _StopData(name: 'Cedar Blvd',         time: '07:37', students: 4, status: 'upcoming',    icon: '📍', note: '4 students waiting'),
  _StopData(name: 'Lincoln Elementary', time: '07:45', students: 0, status: 'destination', icon: '🏫', note: 'Drop-off point'),
];

class _StopRow extends StatelessWidget {
  final _StopData stop;
  final bool isLast;
  const _StopRow({required this.stop, required this.isLast});

  Color get _color => switch (stop.status) {
    'done'        => AppTheme.success,
    'current'     => AppTheme.purple,
    'destination' => AppTheme.warning,
    _             => AppTheme.info,
  };

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 34,
          child: Column(
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: _color.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: _color, width: 2),
                  boxShadow: stop.status == 'current'
                      ? [BoxShadow(color: _color.withOpacity(0.5), blurRadius: 12)]
                      : null,
                ),
                child: Center(
                  child: stop.status == 'done'
                      ? Text('✓', style: TextStyle(color: _color, fontSize: 14, fontWeight: FontWeight.w700))
                      : Text(stop.icon, style: const TextStyle(fontSize: 13)),
                ),
              ),
              if (!isLast)
                Container(
                  width: 2, height: 30,
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
            padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(stop.name,
                            style: TextStyle(
                              color: stop.status == 'current' || stop.status == 'destination'
                                  ? Colors.white : Colors.white.withOpacity(0.75),
                              fontSize: 14,
                              fontWeight: stop.status == 'current' ? FontWeight.w700 : FontWeight.w500,
                            )),
                        if (stop.status == 'current') ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.purple.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppTheme.purple.withOpacity(0.4)),
                            ),
                            child: const Text('NEXT',
                                style: TextStyle(color: AppTheme.parentAccent, fontSize: 9, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(stop.note,
                        style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 11)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${stop.time} AM',
                      style: TextStyle(
                        color: switch (stop.status) {
                          'done'        => AppTheme.successLight,
                          'current'     => AppTheme.parentAccent,
                          'destination' => AppTheme.warning,
                          _             => AppTheme.driverAccent,
                        },
                        fontSize: 13, fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (stop.students > 0)
                      Text('👦 ${stop.students}',
                          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

Widget _backBtn() => Container(
  width: 38, height: 38,
  decoration: BoxDecoration(
    color: Colors.white.withOpacity(0.08),
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: Colors.white.withOpacity(0.12)),
  ),
  child: const Center(child: Text('←', style: TextStyle(color: Colors.white, fontSize: 16))),
);

// ── Custom Painter ─────────────────────────────────────────────────────────────
class _DriverRouteMapPainter extends CustomPainter {
  final double progress;
  _DriverRouteMapPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 340;
    final sy = size.height / 210;
    Offset s(double x, double y) => Offset(x * sx, y * sy);

    final gridPaint = Paint()..color = Colors.white.withOpacity(0.04)..strokeWidth = 1;
    for (final y in [42.0, 84.0, 126.0, 168.0]) {
      canvas.drawLine(s(0, y), s(340, y), gridPaint);
    }
    for (final x in [68.0, 136.0, 204.0, 272.0]) {
      canvas.drawLine(s(x, 0), s(x, 210), gridPaint);
    }

    final roadPaint = Paint()
      ..color = Colors.white.withOpacity(0.12)
      ..strokeWidth = 10 * sx
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(s(20, 155), s(320, 155), roadPaint);
    canvas.drawLine(s(100, 20),  s(100, 165), roadPaint);
    canvas.drawLine(s(20, 82),   s(320, 82),  roadPaint);

    final dashPaint = Paint()
      ..color = AppTheme.driverCyan.withOpacity(0.35)
      ..strokeWidth = 3 * sx
      ..strokeCap = StrokeCap.round;
    _drawDashedPolyline(canvas, [s(50, 155), s(100, 155), s(100, 82), s(220, 82), s(300, 82)], dashPaint);

    final donePaint = Paint()..color = AppTheme.success..strokeWidth = 3 * sx..strokeCap = StrokeCap.round;
    final busProgress = 0.3 + progress * 0.35;
    canvas.drawLine(s(50, 155), s(100, 155), donePaint);
    canvas.drawLine(s(100, 155), s(100, 82), donePaint);
    canvas.drawLine(s(100, 82), s(100 + busProgress * 200, 82), donePaint);

    final stopDefs = [
      (50.0, 155.0, 'done'), (100.0, 155.0, 'done'), (100.0, 120.0, 'done'),
      (100.0, 82.0, 'current'), (220.0, 82.0, 'upcoming'), (300.0, 82.0, 'destination'),
    ];
    for (final st in stopDefs) {
      final center = s(st.$1, st.$2);
      final col = switch (st.$3) {
        'done'        => AppTheme.success,
        'current'     => AppTheme.purple,
        'destination' => AppTheme.warning,
        _             => AppTheme.info,
      };
      canvas.drawCircle(center, 10 * sx, Paint()..color = col.withOpacity(0.2));
      canvas.drawCircle(center, 10 * sx, Paint()..color = col..style = PaintingStyle.stroke..strokeWidth = 2);
      canvas.drawCircle(center, 4 * sx, Paint()..color = col);
      if (st.$3 == 'destination') {
        final tp = TextPainter(text: const TextSpan(text: '🏫', style: TextStyle(fontSize: 14)), textDirection: TextDirection.ltr)..layout();
        tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2 + 18 * sy));
      }
    }

    final busX = 100 + busProgress * 200;
    const busY = 82.0;
    final busCenter = s(busX, busY);
    final busRect = Rect.fromCenter(center: busCenter, width: 28 * sx, height: 28 * sy);
    final rrect = RRect.fromRectAndRadius(busRect, Radius.circular(8 * sx));
    canvas.drawRRect(rrect, Paint()..color = AppTheme.driverCyan.withOpacity(0.9));
    canvas.drawRRect(rrect, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 1.5);
    final tp = TextPainter(text: const TextSpan(text: '🚌', style: TextStyle(fontSize: 14)), textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, busCenter - Offset(tp.width / 2, tp.height / 2));
  }

  void _drawDashedPolyline(Canvas canvas, List<Offset> pts, Paint paint) {
    for (int i = 0; i < pts.length - 1; i++) {
      _drawDashedLine(canvas, pts[i], pts[i + 1], paint);
    }
  }

  void _drawDashedLine(Canvas canvas, Offset s, Offset e, Paint paint) {
    const dl = 6.0, gl = 4.0;
    final dx = e.dx - s.dx, dy = e.dy - s.dy;
    final dist = sqrt(dx * dx + dy * dy);
    final sx2 = dx / dist, sy2 = dy / dist;
    double drawn = 0; bool draw = true;
    double x = s.dx, y = s.dy;
    while (drawn < dist) {
      final step = draw ? dl : gl;
      final len = min(step, dist - drawn);
      final nx = x + sx2 * len, ny = y + sy2 * len;
      if (draw) canvas.drawLine(Offset(x, y), Offset(nx, ny), paint);
      x = nx; y = ny; drawn += len; draw = !draw;
    }
  }

  @override
  bool shouldRepaint(_DriverRouteMapPainter old) => old.progress != progress;
}
