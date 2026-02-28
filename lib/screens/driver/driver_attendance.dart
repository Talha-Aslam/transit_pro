import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

class DriverAttendance extends StatefulWidget {
  final VoidCallback onBack;
  const DriverAttendance({super.key, required this.onBack});

  @override
  State<DriverAttendance> createState() => _DriverAttendanceState();
}

class _DriverAttendanceState extends State<DriverAttendance> {
  late List<_Student> _students;
  String _search = '';
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _students = List.from(_initialStudents);
  }

  void _toggleStatus(int id) {
    setState(() {
      final i = _students.indexWhere((s) => s.id == id);
      final next = switch (_students[i].status) {
        'waiting'  => 'boarded',
        'boarded'  => 'absent',
        _          => 'waiting',
      };
      _students[i] = _students[i].copyWith(status: next);
    });
  }

  int get _boarded => _students.where((s) => s.status == 'boarded').length;
  int get _waiting  => _students.where((s) => s.status == 'waiting').length;
  int get _absent   => _students.where((s) => s.status == 'absent').length;

  List<_Student> get _filtered => _students.where((s) {
    final matchSearch = s.name.toLowerCase().contains(_search.toLowerCase()) ||
        s.stop.toLowerCase().contains(_search.toLowerCase());
    final matchFilter = _filter == 'all' || s.status == _filter;
    return matchSearch && matchFilter;
  }).toList();

  @override
  Widget build(BuildContext context) {
    final stops = _filtered.map((s) => s.stop).toSet().toList();

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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Student Attendance',
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                    Text('Morning Run · Bus #42',
                        style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13)),
                  ],
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Summary row ───────────────────────────────────────────
                Row(
                  children: [
                    _SummaryCard(icon: '✅', label: 'Boarded', value: _boarded, color: AppTheme.success),
                    const SizedBox(width: 10),
                    _SummaryCard(icon: '⏳', label: 'Waiting',  value: _waiting,  color: AppTheme.warning),
                    const SizedBox(width: 10),
                    _SummaryCard(icon: '❌', label: 'Absent',   value: _absent,   color: AppTheme.error),
                  ],
                ),
                const SizedBox(height: 12),

                // ── Progress bar ──────────────────────────────────────────
                GlassCard(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Boarding Progress',
                              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13)),
                          Text('$_boarded/${_students.length} students',
                              style: const TextStyle(color: AppTheme.driverAccent, fontSize: 13, fontWeight: FontWeight.w700)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _boarded / _students.length,
                          backgroundColor: Colors.white.withOpacity(0.08),
                          valueColor: const AlwaysStoppedAnimation(AppTheme.success),
                          minHeight: 8,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ── Search ────────────────────────────────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Row(
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(left: 14),
                        child: Text('🔍', style: TextStyle(fontSize: 16)),
                      ),
                      Expanded(
                        child: TextField(
                          onChanged: (v) => setState(() => _search = v),
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Search student or stop...',
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            hintStyle: TextStyle(color: Colors.white.withOpacity(0.25)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ── Filter tabs ───────────────────────────────────────────
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _filterBtn('all',     'All (${_students.length})'),
                      _filterBtn('boarded', '✅ $_boarded'),
                      _filterBtn('waiting', '⏳ $_waiting'),
                      _filterBtn('absent',  '❌ $_absent'),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // ── Student list grouped by stop ──────────────────────────
                if (_filtered.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Column(
                        children: [
                          const Text('🔍', style: TextStyle(fontSize: 40)),
                          const SizedBox(height: 12),
                          Text('No students found',
                              style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14)),
                        ],
                      ),
                    ),
                  )
                else
                  ...stops.map((stop) {
                    final stopStudents = _filtered.where((s) => s.stop == stop).toList();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Text('📍 $stop',
                                  style: TextStyle(color: Colors.white.withOpacity(0.55),
                                      fontSize: 12, fontWeight: FontWeight.w600)),
                              const SizedBox(width: 8),
                              Expanded(child: Container(height: 1, color: Colors.white.withOpacity(0.08))),
                            ],
                          ),
                        ),
                        ...stopStudents.map((student) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _StudentCard(
                                student: student,
                                onToggle: () => _toggleStatus(student.id),
                              ),
                            )),
                        const SizedBox(height: 8),
                      ],
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterBtn(String key, String label) {
    final active = _filter == key;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _filter = key),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: active ? AppTheme.driverCyan.withOpacity(0.15) : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: active ? AppTheme.driverCyan.withOpacity(0.5) : Colors.white.withOpacity(0.1),
            ),
          ),
          child: Text(label,
              style: TextStyle(
                color: active ? AppTheme.driverAccent : Colors.white.withOpacity(0.5),
                fontSize: 12, fontWeight: active ? FontWeight.w700 : FontWeight.w400,
              )),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String icon, label;
  final int value;
  final Color color;
  const _SummaryCard({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 4),
            Text('$value', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
            Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _StudentCard extends StatelessWidget {
  final _Student student;
  final VoidCallback onToggle;
  const _StudentCard({required this.student, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final cfg = _statusConfig[student.status]!;
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(child: Text(student.avatar, style: const TextStyle(fontSize: 22))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(student.name,
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('${student.grade} · ${student.parentPhone}',
                    style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12)),
              ],
            ),
          ),
          GestureDetector(
            onTap: onToggle,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: cfg.color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: cfg.color.withOpacity(0.3)),
              ),
              child: Text('${cfg.icon} ${cfg.label}',
                  style: TextStyle(color: cfg.color, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
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

class _StatusConfig {
  final Color color;
  final String icon, label;
  const _StatusConfig({required this.color, required this.icon, required this.label});
}

const _statusConfig = {
  'boarded': _StatusConfig(color: AppTheme.success, icon: '✅', label: 'Boarded'),
  'waiting': _StatusConfig(color: AppTheme.warning, icon: '⏳', label: 'Waiting'),
  'absent':  _StatusConfig(color: AppTheme.error,   icon: '❌', label: 'Absent'),
};

class _Student {
  final int id;
  final String name, grade, stop, status, avatar, parentPhone;
  const _Student({required this.id, required this.name, required this.grade, required this.stop,
      required this.status, required this.avatar, required this.parentPhone});
  _Student copyWith({String? status}) => _Student(id: id, name: name, grade: grade, stop: stop,
      status: status ?? this.status, avatar: avatar, parentPhone: parentPhone);
}

const _initialStudents = [
  _Student(id: 1,  name: 'Emma Johnson',      grade: 'Grade 5', stop: 'Oak Street',   status: 'boarded', avatar: '👧', parentPhone: '+1 555-0101'),
  _Student(id: 2,  name: 'Liam Williams',     grade: 'Grade 3', stop: 'Oak Street',   status: 'boarded', avatar: '👦', parentPhone: '+1 555-0102'),
  _Student(id: 3,  name: 'Olivia Davis',      grade: 'Grade 4', stop: 'Maple Avenue', status: 'boarded', avatar: '👧', parentPhone: '+1 555-0103'),
  _Student(id: 4,  name: 'Noah Brown',        grade: 'Grade 6', stop: 'Maple Avenue', status: 'boarded', avatar: '👦', parentPhone: '+1 555-0104'),
  _Student(id: 5,  name: 'Ava Martinez',      grade: 'Grade 2', stop: 'Pine Road',    status: 'boarded', avatar: '👧', parentPhone: '+1 555-0105'),
  _Student(id: 6,  name: 'William Wilson',    grade: 'Grade 5', stop: 'Pine Road',    status: 'boarded', avatar: '👦', parentPhone: '+1 555-0106'),
  _Student(id: 7,  name: 'Sophia Anderson',   grade: 'Grade 3', stop: 'Cedar Blvd',   status: 'waiting', avatar: '👧', parentPhone: '+1 555-0107'),
  _Student(id: 8,  name: 'James Taylor',      grade: 'Grade 4', stop: 'Cedar Blvd',   status: 'waiting', avatar: '👦', parentPhone: '+1 555-0108'),
  _Student(id: 9,  name: 'Isabella Thomas',   grade: 'Grade 6', stop: 'Cedar Blvd',   status: 'absent',  avatar: '👧', parentPhone: '+1 555-0109'),
  _Student(id: 10, name: 'Benjamin Jackson',  grade: 'Grade 2', stop: 'Cedar Blvd',   status: 'waiting', avatar: '👦', parentPhone: '+1 555-0110'),
  _Student(id: 11, name: 'Mia White',         grade: 'Grade 5', stop: 'Oak Street',   status: 'boarded', avatar: '👧', parentPhone: '+1 555-0111'),
  _Student(id: 12, name: 'Lucas Harris',      grade: 'Grade 3', stop: 'Maple Avenue', status: 'boarded', avatar: '👦', parentPhone: '+1 555-0112'),
];
