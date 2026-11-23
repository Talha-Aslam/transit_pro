import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:transit_core/transit_core.dart';

import '../../app/ride_match_service.dart';
import '../../app/session_service.dart';
import '../../data/ride_request_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/profile_form_fields.dart';

/// Where a driver edits the two things that decide whether families can find and
/// book them: the institutions they serve, and the rounds they run.
///
/// The same fields are collected at sign-up. This screen exists because both
/// change constantly in practice — a driver picks up a new school, drops a round,
/// adds seats for a bigger van — and none of that should require support.
///
/// ## What this screen deliberately cannot do
///
/// It cannot change `bookedSeats`. The form carries the live value through
/// read-only and `RideMatchService.mergeRounds` merges it back from the current
/// document, so editing a round's start time cannot silently un-book the families
/// already on it. It also refuses to shrink a round below what is booked, or
/// delete a round that still has students, rather than leaving those families
/// pointing at a round that no longer exists.
class DriverServiceScreen extends StatefulWidget {
  const DriverServiceScreen({super.key});

  @override
  State<DriverServiceScreen> createState() => _DriverServiceScreenState();
}

class _DriverServiceScreenState extends State<DriverServiceScreen> {
  final _session = SessionService.instance;

  List<ServiceAreaFormData> _areas = [];

  /// The institute names the driver has typed in the step above, for the
  /// round cards to offer as chips. Blank cards are skipped — a half-typed
  /// area is not something to tick a round against.
  List<String> get _instituteNames => [
    for (final a in _areas)
      if (a.nameCtrl.text.trim().isNotEmpty) a.nameCtrl.text.trim(),
  ];

  List<RoundFormData> _rounds = [];
  GeoCoord? _base;
  final _fareCtrl = TextEditingController();

  /// Seats in the vehicle. Every round is capped at this.
  final _capacityCtrl = TextEditingController();

  int get _capacity => int.tryParse(_capacityCtrl.text.trim()) ?? 0;

  /// True once the live driver document has been loaded into the form.
  ///
  /// Without this the driver stream would overwrite the form on every emission,
  /// including the one caused by the driver's own save — so a second edit would
  /// start from stale text, and typing while a snapshot arrived would lose
  /// characters.
  bool _loaded = false;
  bool _saving = false;
  String _error = '';

  /// Problems found on individual rounds, by round id, shown on the card.
  Map<String, String> _roundErrors = const {};
  final _roundKeys = <String, GlobalKey>{};
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _session.driver.addListener(_onDriver);
    _onDriver();
  }

  @override
  void dispose() {
    _session.driver.removeListener(_onDriver);
    _fareCtrl.dispose();
    _capacityCtrl.dispose();
    _scroll.dispose();
    _disposeForm();
    super.dispose();
  }

  void _disposeForm() {
    for (final a in _areas) {
      a.dispose();
    }
    for (final r in _rounds) {
      r.dispose();
    }
  }

  void _onDriver() {
    if (_loaded) return;
    final driver = _session.driver.value;
    if (driver == null) return;

    _disposeForm();
    setState(() {
      _loaded = true;
      _areas = driver.serviceAreas.isEmpty
          ? [ServiceAreaFormData()]
          : driver.serviceAreas.map(ServiceAreaFormData.from).toList();
      _rounds = driver.schedules.isEmpty
          ? [RoundFormData.fresh(ordinal: 1)]
          : driver.orderedSchedules.map(RoundFormData.from).toList();
      _base = driver.baseLocation;
      final capacity = driver.vehicleCapacity > 0
          ? driver.vehicleCapacity
          : _session.bus.value?.capacity ?? 0;
      _capacityCtrl.text = capacity > 0 ? '$capacity' : '';
      _fareCtrl.text = driver.missedBusFarePaisa <= 0
          ? ''
          : (driver.missedBusFarePaisa / 100).round().toString();
    });
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final areas = _areas
        .where((a) => !a.isBlank)
        .map((a) => a.toModel())
        .toList();
    // A round keeps only the institutes still listed above: one the driver
    // renamed or removed would otherwise stay ticked out of sight, and the
    // round would go on promising a school the driver no longer serves.
    final names = areas.map((a) => a.name).toSet();
    final rounds = [
      for (final r in _rounds)
        () {
          final m = r.toModel();
          return m.copyWith(
            institutes: m.institutes.where(names.contains).toList(),
          );
        }(),
    ];

    // Same two invariants the sign-up validator enforces, restated here because
    // a driver can otherwise *remove* their last school or round after sign-up
    // and end up invisible with a profile that still reads as complete.
    if (areas.isEmpty) {
      return _fail(
        'Add at least one school, college or university, or no parent can '
        'find you.',
      );
    }
    if (rounds.isEmpty) {
      return _fail(
        'Add at least one round, or there is nothing for a family to book.',
      );
    }
    final capacity = _capacity;
    if (capacity <= 0) {
      return _fail('Enter how many seats your vehicle has.');
    }
    final problems = {
      for (final r in rounds) r.id: ?roundProblem(r, capacity: capacity),
    };
    if (problems.isNotEmpty) {
      setState(() => _roundErrors = problems);
      final first = rounds.firstWhere((r) => problems.containsKey(r.id));
      return _fail(
        problems.length == 1
            ? '"${first.label}": ${problems[first.id]}'
            : '${problems.length} rounds need fixing — see the cards marked '
                  'in red.',
        scrollTo: first.id,
      );
    }

    setState(() {
      _saving = true;
      _error = '';
      _roundErrors = const {};
    });

    final fareRupees = int.tryParse(_fareCtrl.text.trim()) ?? 0;

    try {
      final synced = await RideMatchService.instance.saveService(
        areas: areas,
        rounds: rounds,
        vehicleCapacity: capacity,
        baseLocation: _base,
        missedBusFarePaisa: fareRupees <= 0 ? 0 : fareRupees * 100,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            synced
                ? 'Saved. Parents searching your schools will see this.'
                : 'Saved on this phone. It will reach parents as soon as '
                      "you're back online.",
          ),
          backgroundColor: synced ? AppTheme.success : AppTheme.warning,
        ),
      );
      context.pop();
    } on RideRequestException catch (e) {
      _fail(e.message);
    } catch (e) {
      debugPrint('saving driver service failed: $e');
      _fail('Could not save. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Says why a save did not happen, where the driver is looking: beside the
  /// Save button, in a snackbar, and — when one round is the problem — by
  /// scrolling that round into view. The message used to appear only at the
  /// top of the page, out of sight of the button that caused it, so a
  /// refused save looked exactly like a save that did nothing.
  void _fail(String message, {String? scrollTo}) {
    if (!mounted) return;
    setState(() => _error = message);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppTheme.error),
      );
    final target = scrollTo == null ? null : _roundKeys[scrollTo];
    final ctx = target?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 350),
        alignment: 0.1,
      );
    }
  }

  /// Removing a round families are booked on would strand them, so it is
  /// refused here, at the tap, with the reason — not later at Save.
  Future<void> _removeRound(int index) async {
    final round = _rounds[index];
    if (round.bookedSeats > 0) {
      final name = round.labelCtrl.text.trim().isEmpty
          ? 'This round'
          : '"${round.labelCtrl.text.trim()}"';
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Students are booked on this round'),
          content: Text(
            '$name has ${round.bookedSeats} '
            'student${round.bookedSeats == 1 ? '' : 's'} booked. Move or '
            'remove them from Booked Students first, then delete the round.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }
    setState(() {
      _roundKeys.remove(round.id);
      _roundErrors = {..._roundErrors}..remove(round.id);
      _rounds.removeAt(index);
    });
    // Disposed after the frame, once no text field is still attached.
    WidgetsBinding.instance.addPostFrameCallback((_) => round.dispose());
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: context.scaffoldBg,
        child: SafeArea(
          child: Column(
            children: [
              _header(),
              Expanded(
                child: !_loaded
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _heading(
                              'Where you drive',
                              'Parents search by their child\'s school, so list '
                                  'every institution you run to.',
                            ),
                            const SizedBox(height: 14),
                            ..._areas.asMap().entries.map(
                              (e) => ServiceAreaCard(
                                key: ObjectKey(e.value),
                                index: e.key,
                                data: e.value,
                                canRemove: _areas.length > 1,
                                onRemove: () {
                                  final area = _areas[e.key];
                                  setState(() => _areas.removeAt(e.key));
                                  WidgetsBinding.instance.addPostFrameCallback(
                                    (_) => area.dispose(),
                                  );
                                },
                                onChanged: () => setState(() {}),
                              ),
                            ),
                            _addButton(
                              'Add another destination',
                              () => setState(
                                () => _areas.add(ServiceAreaFormData()),
                              ),
                            ),
                            const SizedBox(height: 18),
                            const FieldLabel('YOUR STARTING POINT'),
                            const SizedBox(height: 8),
                            MapPointField(
                              placeholder: 'Tap to pin where you start',
                              value: _base,
                              accentColor: AppTheme.driverCyan,
                              onPicked: (p) => setState(() => _base = p),
                            ),
                            const SizedBox(height: 20),
                            _heading(
                              'Missed-bus pickup fare',
                              'What you charge for an ad-hoc pickup when a '
                                  'family misses their regular bus. Paid to '
                                  'you directly — the app just shows this '
                                  'number to the family before they request '
                                  'you.',
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _fareCtrl,
                              keyboardType: TextInputType.number,
                              style: TextStyle(color: context.textPrimary),
                              decoration: InputDecoration(
                                prefixText: 'Rs. ',
                                prefixStyle: TextStyle(
                                  color: context.textPrimary,
                                ),
                                hintText: 'e.g. 150 (leave blank if unsure)',
                                hintStyle: TextStyle(color: context.textHint),
                                filled: true,
                                fillColor: context.inputFill,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: context.inputBorder,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            _heading(
                              'Vehicle capacity',
                              'How many seats your vehicle has. No round can '
                                  'offer more than this — every round is the '
                                  'same vehicle making the trip again.',
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _capacityCtrl,
                              keyboardType: TextInputType.number,
                              onChanged: (_) => setState(() {}),
                              style: TextStyle(color: context.textPrimary),
                              decoration: InputDecoration(
                                hintText: 'e.g. 12',
                                hintStyle: TextStyle(color: context.textHint),
                                suffixText: 'seats',
                                filled: true,
                                fillColor: context.inputFill,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: context.inputBorder,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            _heading(
                              'Your rounds',
                              'One round per trip. Seats are counted per round, '
                                  'so the same vehicle offers a full load on '
                                  'each.',
                            ),
                            const SizedBox(height: 14),
                            ..._rounds.asMap().entries.map(
                              (e) => RoundCard(
                                key: _roundKeys.putIfAbsent(
                                  e.value.id,
                                  GlobalKey.new,
                                ),
                                index: e.key,
                                data: e.value,
                                availableInstitutes: _instituteNames,
                                canRemove: _rounds.length > 1,
                                error: _roundErrors[e.value.id],
                                onRemove: () => _removeRound(e.key),
                                onChanged: () => setState(() {
                                  // An edited round is re-checked at Save;
                                  // until then its old complaint is stale.
                                  if (_roundErrors.containsKey(e.value.id)) {
                                    _roundErrors = {..._roundErrors}
                                      ..remove(e.value.id);
                                  }
                                }),
                              ),
                            ),
                            _addButton(
                              'Add another round',
                              () => setState(() {
                                _rounds.add(
                                  RoundFormData.fresh(
                                    ordinal: _rounds.length + 1,
                                    seats: _capacity > 0
                                        ? _capacity
                                        : _session.bus.value?.capacity ?? 0,
                                  ),
                                );
                              }),
                            ),
                            const SizedBox(height: 24),
                            if (_error.isNotEmpty) _errorBanner(),
                            _saveButton(),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() => Container(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          AppTheme.driverCyan.withValues(alpha: 0.15),
          Colors.transparent,
        ],
      ),
    ),
    child: Row(
      children: [
        GestureDetector(
          onTap: () => context.pop(),
          child: Icon(Icons.arrow_back, color: context.textPrimary),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'My Service',
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'Schools you serve and the rounds you run',
                style: TextStyle(color: context.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _errorBanner() => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppTheme.error.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppTheme.error.withValues(alpha: 0.35)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.error_outline, color: AppTheme.error, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            _error,
            style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 13),
          ),
        ),
      ],
    ),
  );

  Widget _heading(String title, String subtitle) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: TextStyle(
          color: context.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        subtitle,
        style: TextStyle(color: context.textSecondary, fontSize: 12),
      ),
    ],
  );

  Widget _addButton(String label, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        border: Border.all(
          color: AppTheme.driverCyan.withValues(alpha: 0.5),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.add_circle_outline,
            color: AppTheme.driverCyan,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.driverCyan,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _saveButton() => GestureDetector(
    onTap: _saving ? null : _save,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        gradient: _saving ? null : AppTheme.driverGradient,
        color: _saving ? context.surfaceBorder : null,
        borderRadius: BorderRadius.circular(16),
      ),
      child: _saving
          ? const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white,
                ),
              ),
            )
          : const Text(
              'Save',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
    ),
  );
}

/// What stops [round] being saved, in words for the driver, or null when it
/// is fine. Checked for every round before anything is written.
String? roundProblem(DriverSchedule round, {int capacity = 0}) {
  if (!round.hasPickup && !round.hasDropoff) {
    return 'Set a start time for taking them, bringing them back, or both.';
  }
  if (round.totalSeats <= 0) return 'Enter how many seats this round has.';
  if (capacity > 0 && round.totalSeats > capacity) {
    return 'Your vehicle has $capacity seats, so this round cannot offer '
        '${round.totalSeats}.';
  }
  if (round.totalSeats < round.bookedSeats) {
    return '${round.bookedSeats} students are booked on this round, so seats '
        'cannot go below ${round.bookedSeats}.';
  }
  return null;
}
