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
/// read-only and `RideMatchService.saveSchedules` merges it back from the current
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
  List<RoundFormData> _rounds = [];
  double _radiusKm = 5;
  GeoCoord? _base;
  final _fareCtrl = TextEditingController();

  /// True once the live driver document has been loaded into the form.
  ///
  /// Without this the driver stream would overwrite the form on every emission,
  /// including the one caused by the driver's own save — so a second edit would
  /// start from stale text, and typing while a snapshot arrived would lose
  /// characters.
  bool _loaded = false;
  bool _saving = false;
  String _error = '';

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
      _radiusKm = driver.serviceRadiusKm <= 0
          ? 5
          : driver.serviceRadiusKm.clamp(1, 30);
      _base = driver.baseLocation;
      _fareCtrl.text = driver.missedBusFarePaisa <= 0
          ? ''
          : (driver.missedBusFarePaisa / 100).round().toString();
    });
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    final areas =
        _areas.where((a) => !a.isBlank).map((a) => a.toModel()).toList();
    final rounds = _rounds.map((r) => r.toModel()).toList();

    // Same two invariants the sign-up validator enforces, restated here because
    // a driver can otherwise *remove* their last school or round after sign-up
    // and end up invisible with a profile that still reads as complete.
    if (areas.isEmpty) {
      setState(() => _error =
          'Add at least one school, college or university, or no parent can '
          'find you.');
      return;
    }
    if (rounds.isEmpty) {
      setState(() => _error =
          'Add at least one round, or there is nothing for a family to book.');
      return;
    }
    final gap = rounds.firstWhere(
      (r) => r.startTime.isEmpty || r.totalSeats <= 0,
      orElse: () => const DriverSchedule(id: '', label: ''),
    );
    if (gap.id.isNotEmpty) {
      setState(() => _error =
          '"${gap.label}" needs both a start time and a seat count.');
      return;
    }

    setState(() {
      _saving = true;
      _error = '';
    });

    final fareRupees = int.tryParse(_fareCtrl.text.trim()) ?? 0;

    try {
      await RideMatchService.instance.saveServiceAreas(
        areas: areas,
        radiusKm: _radiusKm,
        baseLocation: _base,
        missedBusFarePaisa: fareRupees <= 0 ? 0 : fareRupees * 100,
      );
      await RideMatchService.instance.saveSchedules(rounds);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saved. Parents searching your schools will see this.'),
          backgroundColor: AppTheme.success,
        ),
      );
      context.pop();
    } on RideRequestException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      debugPrint('saving driver service failed: $e');
      if (mounted) {
        setState(() => _error =
            'Could not save. Check your connection and try again.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_error.isNotEmpty) _errorBanner(),
                            _heading(
                              'Where you drive',
                              'Parents search by their child\'s school, so list '
                                  'every institution you run to.',
                            ),
                            const SizedBox(height: 14),
                            ..._areas.asMap().entries.map(
                              (e) => ServiceAreaCard(
                                index: e.key,
                                data: e.value,
                                canRemove: _areas.length > 1,
                                onRemove: () => setState(() {
                                  _areas[e.key].dispose();
                                  _areas.removeAt(e.key);
                                }),
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
                            const SizedBox(height: 16),
                            FieldLabel(
                              'HOW FAR YOU WILL TRAVEL — '
                              '${_radiusKm.round()} KM',
                            ),
                            Slider(
                              value: _radiusKm,
                              min: 1,
                              max: 30,
                              divisions: 29,
                              activeColor: AppTheme.driverCyan,
                              label: '${_radiusKm.round()} km',
                              onChanged: (v) =>
                                  setState(() => _radiusKm = v),
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
                              'Your rounds',
                              'One round per trip. Seats are counted per round, '
                                  'so the same vehicle offers a full load on '
                                  'each.',
                            ),
                            const SizedBox(height: 14),
                            ..._rounds.asMap().entries.map(
                              (e) => RoundCard(
                                index: e.key,
                                data: e.value,
                                canRemove: _rounds.length > 1,
                                onRemove: () => setState(() {
                                  _rounds[e.key].dispose();
                                  _rounds.removeAt(e.key);
                                }),
                                onChanged: () => setState(() {}),
                              ),
                            ),
                            _addButton(
                              'Add another round',
                              () => setState(() {
                                _rounds.add(
                                  RoundFormData.fresh(
                                    ordinal: _rounds.length + 1,
                                    seats: _session.bus.value?.capacity ?? 0,
                                  ),
                                );
                              }),
                            ),
                            const SizedBox(height: 24),
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
                style: TextStyle(
                  color: context.textSecondary,
                  fontSize: 12,
                ),
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
