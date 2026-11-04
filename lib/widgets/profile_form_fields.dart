import 'dart:async';

import 'package:flutter/material.dart';
import 'package:transit_core/transit_core.dart';

import '../app/language_provider.dart';
import '../app/route_service.dart';
import '../screens/map_picker_screen.dart';
import '../theme/app_theme.dart';

/// Form widgets shared by the sign-up screen and the profile-completion screen.
///
/// These began as private helpers inside `signup_screen.dart`. They live here
/// now because two screens collect the same profile fields, and a duplicated
/// school picker or child card would drift apart the first time either was
/// touched.

// ── Options ─────────────────────────────────────────────────────────────────

const kGradeOptions = ['School', 'College', 'University', 'Academy'];

const kVehicleTypes = [
  'Bus',
  'Van',
  'Carry Daba',
  'Auto Rickshaw',
  'Bike',
  'Car',
];

const kSchoolList = [
  'Beaconhouse School System',
  'The City School',
  'Lahore Grammar School',
  'Roots School System',
  'Allied School',
  'Foundation Public School',
  'Froebels International School',
  'Army Public School',
  'Divisional Public School',
  'Government High School',
  'DHA Suffa University',
  'University of Punjab',
  'COMSATS University',
  'NUST',
  'FAST National University',
  'Aga Khan University',
  'Forman Christian College',
  'Government College University',
  'University of Lahore',
  'UET Lahore',
  'Air University',
  'Quaid-i-Azam University',
  'LUMS',
  'Bahria University',
  'Riphah International University',
];

// ── Field label ─────────────────────────────────────────────────────────────

class FieldLabel extends StatelessWidget {
  final String text;
  final bool important;
  const FieldLabel(this.text, {super.key, this.important = false});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: TextStyle(
          color: context.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
        children: [
          TextSpan(text: text),
          if (important)
            const TextSpan(
              text: ' *',
              style: TextStyle(color: Colors.red),
            ),
        ],
      ),
    );
  }
}

// ── Dropdown ────────────────────────────────────────────────────────────────

class ThemedDropdown extends StatelessWidget {
  final String hint;
  final String? value;
  final List<String> items;
  final void Function(String?) onChanged;

  const ThemedDropdown({
    super.key,
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: context.cardBgElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.inputBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(
            hint,
            style: TextStyle(color: context.textTertiary, fontSize: 14),
          ),
          isExpanded: true,
          dropdownColor: context.cardBgElevated,
          iconEnabledColor: context.textTertiary,
          style: TextStyle(color: context.textPrimary, fontSize: 15),
          items: items
              .map((item) => DropdownMenuItem(value: item, child: Text(item)))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// ── Place autocomplete ──────────────────────────────────────────────────────

/// Searchable place picker backed by Places API (New) — Autocomplete then
/// Place Details, the same two-step, session-tokened flow [MapPickerScreen]
/// uses for its own search box (see `RouteService.searchPlaces`).
///
/// [poiCategory] is passed straight through as Places' `includedPrimaryTypes`.
/// Leave it null — the default — for an unrestricted search, which is what a
/// "where do you live" field wants: streets, sectors, neighbourhoods and
/// landmarks all qualify. [SchoolSearchField] below sets it to the education
/// types so "punjab col..." surfaces actual campuses (with the branch address
/// to disambiguate — e.g. "Airline Campus" vs "Township Campus") rather than
/// generic address matches.
///
/// [onLocationSelected] fires with the resolved coordinates whenever a real
/// suggestion (not a manual entry) is picked, so a caller can drop a pin on a
/// map or stash the point for later without a second lookup.
///
/// The sentinel "+ Add … manually" option — always pinned to the bottom of
/// the results — is how a user enters a place Google has never heard of.
/// [localFallback] is a last-resort list of coordinate-less names merged in
/// only when the live search comes back empty (no key configured, offline, or
/// genuinely no match).
class PlaceSearchField extends StatefulWidget {
  final TextEditingController controller;
  final bool isCustom;
  final void Function(bool) onCustomChanged;
  final Color accentColor;
  final String hintText;

  /// Places' `includedPrimaryTypes`, comma-separated. Null means no type
  /// filter at all.
  final String? poiCategory;

  /// Names shown only when the live search returns nothing.
  final List<String> localFallback;

  /// Biases results toward this point (Places' `locationBias`) — pass the
  /// family's home/city location when known so "Punjab College" resolves to
  /// the nearby campus first.
  final GeoCoord? near;

  /// Called with the place's coordinates when a live search result (not a
  /// manual entry, which has no known location) is selected.
  final ValueChanged<GeoCoord>? onLocationSelected;

  const PlaceSearchField({
    super.key,
    required this.controller,
    required this.isCustom,
    required this.onCustomChanged,
    required this.hintText,
    this.accentColor = AppTheme.parentAccent,
    this.poiCategory,
    this.localFallback = const [],
    this.near,
    this.onLocationSelected,
  });

  @override
  State<PlaceSearchField> createState() => _PlaceSearchFieldState();
}

class _PlaceSearchFieldState extends State<PlaceSearchField> {
  final _layerLink = LayerLink();
  final _overlayController = OverlayPortalController();
  final _focusNode = FocusNode();

  Timer? _debounce;
  String? _sessionToken;
  List<GeocodeResult> _results = [];
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) _overlayController.hide();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String query) {
    widget.controller.text = query;
    final trimmed = query.trim();
    _debounce?.cancel();

    if (trimmed.isEmpty) {
      _sessionToken = null;
      setState(() {
        _results = [];
        _searching = false;
      });
      _overlayController.hide();
      return;
    }

    _overlayController.show();
    // First keystroke of a search opens a Places Autocomplete session;
    // reused for every autocomplete/details call until the field goes back
    // to empty, per Google's per-session billing model (mirrors
    // MapPickerScreen).
    final token = _sessionToken ??= RouteService.newSessionToken();
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      final results = await RouteService.instance.searchPlaces(
        trimmed,
        sessionToken: token,
        near: widget.near,
        poiCategory: widget.poiCategory,
      );
      // The field may have moved on to a different query while this was in
      // flight — never let a slow, stale response overwrite it.
      if (!mounted || widget.controller.text.trim() != trimmed) return;
      setState(() {
        _results = results.isNotEmpty ? results : _localFallback(trimmed);
        _searching = false;
      });
    });
  }

  /// Local, coordinate-less matches from [PlaceSearchField.localFallback] —
  /// only used when the live API genuinely found nothing (commonly: no Google
  /// Maps API key configured on this build, or the device is offline).
  List<GeocodeResult> _localFallback(String query) {
    final lower = query.toLowerCase();
    return widget.localFallback
        .where((s) => s.toLowerCase().contains(lower))
        .map((s) => GeocodeResult(label: s, coord: const GeoCoord(0, 0)))
        .toList();
  }

  void _selectResult(GeocodeResult result) {
    final name = result.name ?? result.label;
    widget.controller.text = name;
    widget.onCustomChanged(false);
    // The local fallback path has no real coordinate — only forward a point
    // that actually came back from Google.
    if (result.placeFormatted != null || result.name != null) {
      widget.onLocationSelected?.call(result.coord);
    }
    _overlayController.hide();
    _focusNode.unfocus();
    setState(() => _results = []);
  }

  void _selectManual(String typed) {
    widget.controller.text = typed;
    widget.onCustomChanged(true);
    _overlayController.hide();
    _focusNode.unfocus();
    setState(() => _results = []);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fieldWidth = constraints.maxWidth;
        return CompositedTransformTarget(
          link: _layerLink,
          child: OverlayPortal(
            controller: _overlayController,
            overlayChildBuilder: (overlayCtx) => CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              targetAnchor: Alignment.bottomLeft,
              followerAnchor: Alignment.topLeft,
              offset: const Offset(0, 6),
              child: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: fieldWidth,
                  child: _buildResults(overlayCtx),
                ),
              ),
            ),
            child: TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              onChanged: _onChanged,
              onTap: () {
                if (widget.controller.text.trim().isNotEmpty) {
                  _overlayController.show();
                }
              },
              style: TextStyle(color: context.textPrimary, fontSize: 15),
              decoration: InputDecoration(
                hintText: widget.hintText,
                suffixIcon: _searching
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : (widget.isCustom
                          ? Icon(
                              Icons.edit_note,
                              color: widget.accentColor,
                              size: 20,
                            )
                          : Icon(
                              Icons.search,
                              color: context.textTertiary,
                              size: 18,
                            )),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildResults(BuildContext context) {
    final query = widget.controller.text.trim();
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(12),
      color: context.cardBgElevated,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 260),
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 6),
          shrinkWrap: true,
          children: [
            for (final r in _results)
              InkWell(
                onTap: () => _selectResult(r),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.name ?? r.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if ((r.placeFormatted ?? '').isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            r.placeFormatted!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: context.textTertiary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            if (_results.isNotEmpty && query.isNotEmpty)
              Divider(height: 1, color: context.surfaceBorder),
            if (query.isNotEmpty)
              InkWell(
                onTap: () => _selectManual(query),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 11,
                  ),
                  child: Text(
                    '+ Add "$query" manually',
                    style: TextStyle(
                      color: widget.accentColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── School autocomplete ─────────────────────────────────────────────────────

/// [PlaceSearchField] narrowed to schools/campuses.
///
/// [kSchoolList] is kept as the local fallback for when the live search comes
/// back empty, same as the old hardcoded-list version offered.
class SchoolSearchField extends StatelessWidget {
  final TextEditingController controller;
  final bool isCustom;
  final void Function(bool) onCustomChanged;
  final Color accentColor;
  final GeoCoord? near;
  final ValueChanged<GeoCoord>? onLocationSelected;

  // Google place types, sent as Places API (New) `includedPrimaryTypes`.
  // Capped at 5 by Google. There is no "college" type — colleges are indexed
  // as `university` or `school`, so those two cover them.
  static const _poiCategory =
      'school,primary_school,secondary_school,university';

  const SchoolSearchField({
    super.key,
    required this.controller,
    required this.isCustom,
    required this.onCustomChanged,
    this.accentColor = AppTheme.parentAccent,
    this.near,
    this.onLocationSelected,
  });

  @override
  Widget build(BuildContext context) {
    return PlaceSearchField(
      controller: controller,
      isCustom: isCustom,
      onCustomChanged: onCustomChanged,
      accentColor: accentColor,
      near: near,
      onLocationSelected: onLocationSelected,
      hintText: AppStrings.t('search_school_hint'),
      poiCategory: _poiCategory,
      localFallback: kSchoolList,
    );
  }
}

// ── Document upload tile ────────────────────────────────────────────────────

class DocumentUploadTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final bool isDone;
  final VoidCallback onTap;

  const DocumentUploadTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.onTap,
    this.isDone = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: accentColor.withValues(alpha: isDone ? 0.6 : 0.28),
            width: isDone ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: accentColor, size: 18),
                ),
                const Spacer(),
                Icon(
                  isDone
                      ? Icons.check_circle_rounded
                      : Icons.upload_file_rounded,
                  color: accentColor,
                  size: 18,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: context.textSecondary, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Map point picker ────────────────────────────────────────────────────────

/// Tappable row that opens the map picker and shows the chosen coordinates.
///
/// Reverse-geocodes the pin into a human address ("Model Town, Lahore") when
/// [RouteService] has a key configured; falls back to raw coordinates while
/// that lookup is in flight, on failure, or with no key at all — coordinates
/// are always a truthful thing to show, never a dead end.
class MapPointField extends StatefulWidget {
  final String placeholder;
  final GeoCoord? value;
  final ValueChanged<GeoCoord> onPicked;

  /// Fires whenever the human-readable address for [value] becomes known —
  /// right away if the picker already resolved it, or a little later once
  /// this field's own reverse-geocode lookup completes. `null` means "not
  /// resolved (yet)", not "no address" — callers that need a string to
  /// persist should fall back to formatted coordinates rather than treat
  /// `null` as final.
  final ValueChanged<String?>? onAddressResolved;

  /// Tints the picker screen's pin/confirm button/FAB so it reads as part of
  /// whichever role's form opened it.
  final Color accentColor;

  /// Where to start the picker's pin when [value] is still unset — e.g. a
  /// campus location just resolved by [SchoolSearchField], so the map opens
  /// near the school instead of [MapPickerScreen]'s hardcoded Lahore-centre
  /// default. Ignored once [value] is set; never overrides a point the user
  /// already chose.
  final GeoCoord? fallbackInitial;

  const MapPointField({
    super.key,
    required this.placeholder,
    required this.value,
    required this.onPicked,
    this.onAddressResolved,
    this.accentColor = AppTheme.parentPurple,
    this.fallbackInitial,
  });

  @override
  State<MapPointField> createState() => _MapPointFieldState();
}

class _MapPointFieldState extends State<MapPointField> {
  String? _address;
  GeoCoord? _addressFor;

  @override
  void initState() {
    super.initState();
    _maybeGeocode();
  }

  @override
  void didUpdateWidget(MapPointField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) _maybeGeocode();
  }

  void _maybeGeocode() {
    final point = widget.value;
    // Already resolved for this exact point — most commonly because the map
    // picker itself just did the lookup and handed the address straight
    // back, so there's nothing to re-fetch over the network.
    if (point == null || _addressFor == point) return;
    unawaited(() async {
      final address = await RouteService.instance.reverseGeocode(point);
      // The field may have moved on to a different pin (or been disposed)
      // while the request was in flight — don't overwrite a newer result.
      if (!mounted || widget.value != point) return;
      setState(() {
        _addressFor = point;
        _address = address;
      });
      widget.onAddressResolved?.call(address);
    }());
  }

  String get _coordinateLabel =>
      '${widget.value!.lat.toStringAsFixed(6)}, '
      '${widget.value!.lng.toStringAsFixed(6)}';

  @override
  Widget build(BuildContext context) {
    final value = widget.value;
    final label = value == null
        ? widget.placeholder
        : (_addressFor == value ? _address : null) ?? _coordinateLabel;

    return GestureDetector(
      onTap: () async {
        final result = await Navigator.of(context).push<PickedLocation?>(
          MaterialPageRoute(
            builder: (_) => MapPickerScreen(
              initial: value ?? widget.fallbackInitial,
              accentColor: widget.accentColor,
            ),
          ),
        );
        if (result == null) return;
        // The picker already resolved this, if it could — cache it so
        // `_maybeGeocode` (fired next by `didUpdateWidget`) doesn't spend a
        // second network round trip re-resolving the same point.
        if (result.address != null) {
          setState(() {
            _addressFor = result.coord;
            _address = result.address;
          });
        }
        widget.onPicked(result.coord);
        widget.onAddressResolved?.call(result.address);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: context.cardBgElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.inputBorder),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: value == null
                      ? context.textTertiary
                      : context.textPrimary,
                  fontSize: 15,
                ),
              ),
            ),
            Icon(Icons.map, color: context.textTertiary),
          ],
        ),
      ),
    );
  }
}

// ── Child form ──────────────────────────────────────────────────────────────

/// Controllers for one child card. Owned by the parent screen so it can dispose
/// them.
class ChildFormData {
  final nameCtrl = TextEditingController();

  /// Free-typed grade/class, e.g. "Grade 5", "O-Level" — distinct from
  /// [instituteType] below. See `ChildDraft.grade`'s doc comment for why
  /// these used to be the same field and why that broke "Edit Info"'s
  /// pre-population.
  final gradeCtrl = TextEditingController();

  final schoolCtrl = TextEditingController();
  final studentIdCtrl = TextEditingController();

  /// School/College/University/Academy — one of `kGradeOptions`.
  String? instituteType;

  bool isCustomSchool = false;

  /// Where the child is collected from. Optional, but it is what turns driver
  /// search from "these drivers serve your school" into "these drivers serve
  /// your school and are 2 km away".
  GeoCoord? pickup;

  ChildFormData({
    String name = '',
    String grade = '',
    this.instituteType,
    String school = '',
    String studentId = '',
    this.pickup,
  }) {
    nameCtrl.text = name;
    gradeCtrl.text = grade;
    schoolCtrl.text = school;
    studentIdCtrl.text = studentId;
  }

  void dispose() {
    nameCtrl.dispose();
    gradeCtrl.dispose();
    schoolCtrl.dispose();
    studentIdCtrl.dispose();
  }
}

class ChildCard extends StatelessWidget {
  final int index;
  final ChildFormData data;
  final bool canRemove;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const ChildCard({
    super.key,
    required this.index,
    required this.data,
    required this.canRemove,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // This card (and `ServiceAreaCard`/`RoundCard` below) sits inside a large
    // non-virtualized `Column` in a `SingleChildScrollView` — without a
    // boundary, a blinking cursor in any one TextField anywhere on the page
    // forces Flutter to repaint the *entire* form's picture every ~500ms.
    // Isolating each card keeps that repaint scoped to just the card whose
    // field is actually focused.
    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.parentPurple.withValues(
            alpha: context.isDark ? 0.10 : 0.06,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.parentPurple.withValues(
              alpha: context.isDark ? 0.28 : 0.20,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${AppStrings.t('child_lbl')} ${index + 1}',
                  style: const TextStyle(
                    color: AppTheme.parentAccent,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                if (canRemove)
                  GestureDetector(
                    onTap: onRemove,
                    child: const Icon(
                      Icons.remove_circle_outline,
                      color: Colors.redAccent,
                      size: 20,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            FieldLabel(AppStrings.t('childs_name_lbl'), important: true),
            const SizedBox(height: 6),
            TextField(
              controller: data.nameCtrl,
              style: TextStyle(color: context.textPrimary, fontSize: 15),
              decoration: InputDecoration(
                hintText: AppStrings.t('childs_name_hint'),
              ),
            ),
            const SizedBox(height: 12),
            const FieldLabel('GRADE / CLASS', important: true),
            const SizedBox(height: 6),
            TextField(
              controller: data.gradeCtrl,
              style: TextStyle(color: context.textPrimary, fontSize: 15),
              decoration: const InputDecoration(hintText: 'e.g. Grade 5'),
            ),
            const SizedBox(height: 12),
            // Was labelled "GRADE / LEVEL" and stored straight into
            // `ChildDraft.grade` — this dropdown's actual value domain
            // (`kGradeOptions`: School/College/University/Academy) is the
            // institute type, not a grade. See `ChildDraft.grade`'s doc
            // comment.
            FieldLabel(AppStrings.t('grade_level_lbl'), important: true),
            const SizedBox(height: 6),
            ThemedDropdown(
              hint: AppStrings.t('select_level_hint'),
              value: data.instituteType,
              items: kGradeOptions,
              onChanged: (v) {
                data.instituteType = v;
                onChanged();
              },
            ),
            const SizedBox(height: 12),
            FieldLabel(AppStrings.t('school_institution_lbl'), important: true),
            const SizedBox(height: 6),
            SchoolSearchField(
              controller: data.schoolCtrl,
              isCustom: data.isCustomSchool,
              onCustomChanged: (v) {
                data.isCustomSchool = v;
                onChanged();
              },
            ),
            const SizedBox(height: 12),
            const FieldLabel('SCHOOL ROLL NUMBER', important: true),
            const SizedBox(height: 6),
            TextField(
              controller: data.studentIdCtrl,
              style: TextStyle(color: context.textPrimary, fontSize: 15),
              decoration: const InputDecoration(hintText: 'e.g. 12345'),
            ),
            const SizedBox(height: 12),
            const FieldLabel('PICKUP POINT (OPTIONAL)'),
            const SizedBox(height: 6),
            MapPointField(
              placeholder: 'Tap to pin where the van collects them',
              value: data.pickup,
              accentColor: AppTheme.parentAccent,
              onPicked: (p) {
                data.pickup = p;
                onChanged();
              },
            ),
            const SizedBox(height: 6),
            Text(
              'Adding this ranks nearby drivers first when you search.',
              style: TextStyle(color: context.textTertiary, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Driver service areas ────────────────────────────────────────────────────

/// Controllers for one "school I serve" card.
class ServiceAreaFormData {
  final nameCtrl = TextEditingController();
  String? instituteType;
  GeoCoord? location;
  bool isCustomSchool = false;

  ServiceAreaFormData({String name = '', this.instituteType, this.location}) {
    nameCtrl.text = name;
  }

  /// Rebuilds a card from a saved area, so the editor opens showing what the
  /// driver already has rather than a blank form.
  factory ServiceAreaFormData.from(ServiceArea area) => ServiceAreaFormData(
    name: area.name,
    instituteType: area.instituteType,
    location: area.location,
  );

  bool get isBlank => nameCtrl.text.trim().isEmpty;

  ServiceArea toModel() => ServiceArea(
    name: nameCtrl.text.trim(),
    instituteType: instituteType ?? 'School',
    location: location,
  );

  void dispose() => nameCtrl.dispose();
}

class ServiceAreaCard extends StatelessWidget {
  final int index;
  final ServiceAreaFormData data;
  final bool canRemove;
  final VoidCallback onRemove;
  final VoidCallback onChanged;
  final Color accentColor;

  const ServiceAreaCard({
    super.key,
    required this.index,
    required this.data,
    required this.canRemove,
    required this.onRemove,
    required this.onChanged,
    this.accentColor = AppTheme.driverCyan,
  });

  @override
  Widget build(BuildContext context) {
    // See the matching comment on `ChildCard.build` — isolates this card's
    // repaint (cursor blink, focus changes) from every other card and field
    // on the page.
    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha: context.isDark ? 0.10 : 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: accentColor.withValues(alpha: context.isDark ? 0.28 : 0.20),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Destination ${index + 1}',
                  style: TextStyle(
                    color: accentColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                if (canRemove)
                  GestureDetector(
                    onTap: onRemove,
                    child: const Icon(
                      Icons.remove_circle_outline,
                      color: Colors.redAccent,
                      size: 20,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            const FieldLabel('SCHOOL / COLLEGE / UNIVERSITY', important: true),
            const SizedBox(height: 6),
            SchoolSearchField(
              controller: data.nameCtrl,
              isCustom: data.isCustomSchool,
              onCustomChanged: (v) {
                data.isCustomSchool = v;
                onChanged();
              },
              accentColor: accentColor,
            ),
            const SizedBox(height: 12),
            const FieldLabel('TYPE'),
            const SizedBox(height: 6),
            ThemedDropdown(
              hint: 'School, College, University…',
              value: data.instituteType,
              items: kGradeOptions,
              onChanged: (v) {
                data.instituteType = v;
                onChanged();
              },
            ),
            const SizedBox(height: 12),
            const FieldLabel('PIN IT ON THE MAP (OPTIONAL)'),
            const SizedBox(height: 6),
            MapPointField(
              placeholder: 'Tap to pin the campus',
              value: data.location,
              accentColor: accentColor,
              onPicked: (p) {
                data.location = p;
                onChanged();
              },
            ),
            const SizedBox(height: 6),
            Text(
              'Pinning it lets parents nearby see how far you are. Without a pin '
              'you still match by name.',
              style: TextStyle(color: context.textTertiary, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Driver rounds ───────────────────────────────────────────────────────────

/// Controllers for one bookable round.
///
/// [bookedSeats] is carried through read-only. It is shown so a driver can see
/// why a round refuses to shrink, and it is never written from this form — the
/// live value is merged back in by `RideMatchService.saveSchedules`.
class RoundFormData {
  final String id;
  final labelCtrl = TextEditingController();
  final seatsCtrl = TextEditingController();

  /// Home → institute. Null means this round does not run that leg, which is
  /// how a driver describes an evening-only academy run.
  TimeOfDay? pickupStart;
  TimeOfDay? pickupEnd;

  /// Institute → home.
  TimeOfDay? dropoffStart;
  TimeOfDay? dropoffEnd;

  /// Which institutes this round drops at. A single round routinely serves
  /// more than one — half the children at a university, the rest at a
  /// college on the same run — so this is a set, not a choice.
  final Set<String> institutes;

  final int bookedSeats;

  RoundFormData({
    required this.id,
    String label = '',
    String seats = '',
    this.pickupStart,
    this.pickupEnd,
    this.dropoffStart,
    this.dropoffEnd,
    Set<String>? institutes,
    this.bookedSeats = 0,
  }) : institutes = institutes ?? <String>{} {
    labelCtrl.text = label;
    seatsCtrl.text = seats;
  }

  /// A fresh round. The id is minted here, once, and must survive editing — it
  /// is what accepted requests and student records point at.
  factory RoundFormData.fresh({required int ordinal, int seats = 0}) =>
      RoundFormData(
        id:
            'r${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}'
            '$ordinal',
        label: 'Round $ordinal',
        seats: seats > 0 ? '$seats' : '',
      );

  factory RoundFormData.from(DriverSchedule s) => RoundFormData(
    id: s.id,
    label: s.label,
    seats: s.totalSeats > 0 ? '${s.totalSeats}' : '',
    pickupStart: _parseTime(s.pickupStart),
    pickupEnd: _parseTime(s.pickupEnd),
    dropoffStart: _parseTime(s.dropoffStart),
    dropoffEnd: _parseTime(s.dropoffEnd),
    institutes: s.institutes.toSet(),
    bookedSeats: s.bookedSeats,
  );

  /// True once the driver has given this round at least one leg to run.
  bool get hasAnyLeg => pickupStart != null || dropoffStart != null;

  static TimeOfDay? _parseTime(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  static String _formatTime(TimeOfDay? t) => t == null
      ? ''
      : '${t.hour.toString().padLeft(2, '0')}:'
            '${t.minute.toString().padLeft(2, '0')}';

  DriverSchedule toModel() => DriverSchedule(
    id: id,
    label: labelCtrl.text.trim().isEmpty ? 'Round' : labelCtrl.text.trim(),
    pickupStart: _formatTime(pickupStart),
    pickupEnd: _formatTime(pickupEnd),
    dropoffStart: _formatTime(dropoffStart),
    dropoffEnd: _formatTime(dropoffEnd),
    institutes: institutes.toList(),
    totalSeats: int.tryParse(seatsCtrl.text.trim()) ?? 0,
    bookedSeats: bookedSeats,
  );

  void dispose() {
    labelCtrl.dispose();
    seatsCtrl.dispose();
  }
}

class RoundCard extends StatelessWidget {
  final int index;
  final RoundFormData data;
  final bool canRemove;
  final VoidCallback onRemove;
  final VoidCallback onChanged;
  final Color accentColor;

  /// The institutes the driver has listed on their profile, offered here as
  /// chips. Empty while they are still filling in the step above, in which
  /// case the picker explains that rather than showing nothing.
  final List<String> availableInstitutes;

  const RoundCard({
    super.key,
    required this.index,
    required this.data,
    required this.canRemove,
    required this.onRemove,
    required this.onChanged,
    this.availableInstitutes = const [],
    this.accentColor = AppTheme.driverCyan,
  });

  Future<void> _pickTime(
    BuildContext context,
    TimeOfDay? current,
    TimeOfDay fallback,
    void Function(TimeOfDay) assign,
  ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: current ?? fallback,
    );
    if (picked == null) return;
    assign(picked);
    onChanged();
  }

  /// One leg of the round: a heading, the two times, and a way to clear it.
  ///
  /// Clearing matters. A round that only brings children home, or an academy
  /// run that only goes out in the evening, is described by *leaving a leg
  /// empty* — without a Clear there would be no way back from a mis-tapped
  /// time picker, and the driver would be advertising a trip they do not run.
  Widget _leg(
    BuildContext context, {
    required String title,
    required String subtitle,
    required TimeOfDay? start,
    required TimeOfDay? end,
    required TimeOfDay fallbackStart,
    required String startHint,
    required String endHint,
    required void Function(TimeOfDay?) setStart,
    required void Function(TimeOfDay?) setEnd,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (start != null || end != null)
              GestureDetector(
                onTap: () {
                  setStart(null);
                  setEnd(null);
                  onChanged();
                },
                child: Text(
                  'Clear',
                  style: TextStyle(
                    color: context.textTertiary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: TextStyle(color: context.textTertiary, fontSize: 11),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _TimeBox(
                value: RoundFormData._formatTime(start),
                placeholder: startHint,
                onTap: () => _pickTime(
                  context,
                  start,
                  fallbackStart,
                  (t) => setStart(t),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _TimeBox(
                value: RoundFormData._formatTime(end),
                placeholder: endHint,
                onTap: () => _pickTime(
                  context,
                  end,
                  start ?? fallbackStart,
                  (t) => setEnd(t),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final booked = data.bookedSeats;

    // See the matching comment on `ChildCard.build` — isolates this card's
    // repaint (cursor blink, focus changes, time-picker taps) from every
    // other card and field on the page.
    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha: context.isDark ? 0.10 : 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: accentColor.withValues(alpha: context.isDark ? 0.28 : 0.20),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Round ${index + 1}',
                  style: TextStyle(
                    color: accentColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                if (booked > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$booked booked',
                      style: const TextStyle(
                        color: AppTheme.success,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                if (canRemove) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: onRemove,
                    child: const Icon(
                      Icons.remove_circle_outline,
                      color: Colors.redAccent,
                      size: 20,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            const FieldLabel('NAME THIS ROUND'),
            const SizedBox(height: 6),
            TextField(
              controller: data.labelCtrl,
              style: TextStyle(color: context.textPrimary, fontSize: 15),
              decoration: const InputDecoration(
                hintText: 'e.g. Early morning, DHA run',
              ),
            ),
            const SizedBox(height: 12),
            const FieldLabel('WHERE THIS ROUND GOES', important: true),
            const SizedBox(height: 6),
            if (availableInstitutes.isEmpty)
              Text(
                'Add the schools, colleges or universities you serve above, '
                'then come back and tick the ones this round covers.',
                style: TextStyle(color: context.textTertiary, fontSize: 11),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final name in availableInstitutes)
                    _ChoiceChip(
                      label: name,
                      selected: data.institutes.contains(name),
                      accentColor: accentColor,
                      onTap: () {
                        if (!data.institutes.remove(name)) {
                          data.institutes.add(name);
                        }
                        onChanged();
                      },
                    ),
                ],
              ),
            const SizedBox(height: 6),
            Text(
              'One round can drop at more than one place — tick every '
              'institute you pass on this run.',
              style: TextStyle(color: context.textTertiary, fontSize: 11),
            ),
            const SizedBox(height: 14),
            // Two legs, not a direction. The same children ride out and back
            // with this driver on one seat, so the round carries both times;
            // a run that only goes one way simply leaves the other blank.
            _leg(
              context,
              title: 'TAKING THEM  \u2192',
              subtitle: 'From home to the institute',
              start: data.pickupStart,
              end: data.pickupEnd,
              fallbackStart: const TimeOfDay(hour: 6, minute: 30),
              startHint: '06:30',
              endHint: '07:30',
              setStart: (t) => data.pickupStart = t,
              setEnd: (t) => data.pickupEnd = t,
            ),
            const SizedBox(height: 14),
            _leg(
              context,
              title: 'BRINGING THEM BACK  \u2190',
              subtitle: 'From the institute back home',
              start: data.dropoffStart,
              end: data.dropoffEnd,
              fallbackStart: const TimeOfDay(hour: 13, minute: 30),
              startHint: '13:30',
              endHint: '14:30',
              setStart: (t) => data.dropoffStart = t,
              setEnd: (t) => data.dropoffEnd = t,
            ),
            const SizedBox(height: 6),
            Text(
              'Leave a side blank if this round only runs one way.',
              style: TextStyle(color: context.textTertiary, fontSize: 11),
            ),
            const SizedBox(height: 12),
            const FieldLabel('SEATS ON THIS ROUND', important: true),
            const SizedBox(height: 6),
            TextField(
              controller: data.seatsCtrl,
              keyboardType: TextInputType.number,
              style: TextStyle(color: context.textPrimary, fontSize: 15),
              decoration: const InputDecoration(hintText: 'e.g. 12'),
            ),
            const SizedBox(height: 6),
            Text(
              booked > 0
                  ? 'Cannot go below $booked — that many families are already on '
                        'this round.'
                  : 'Seats are counted per round, so the same vehicle can carry a '
                        'full load on each trip.',
              style: TextStyle(color: context.textTertiary, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeBox extends StatelessWidget {
  final String value;
  final String placeholder;
  final VoidCallback onTap;

  const _TimeBox({
    required this.value,
    required this.placeholder,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: context.cardBgElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.inputBorder),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value.isEmpty ? placeholder : value,
                style: TextStyle(
                  color: value.isEmpty
                      ? context.textTertiary
                      : context.textPrimary,
                  fontSize: 15,
                ),
              ),
            ),
            Icon(Icons.schedule, color: context.textTertiary, size: 18),
          ],
        ),
      ),
    );
  }
}

// ── Step dot ────────────────────────────────────────────────────────────────

class StepDot extends StatelessWidget {
  final bool active;
  final Color color;
  const StepDot({super.key, required this.active, required this.color});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? color : context.surfaceBorder,
        border: Border.all(
          color: active ? color : Colors.white.withValues(alpha: 0.2),
          width: 2,
        ),
      ),
    );
  }
}


/// A tick-on/tick-off chip. Small enough that pulling in a Material
/// `FilterChip` would fight this form's styling rather than save anything.
class _ChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color accentColor;
  final VoidCallback onTap;

  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? accentColor.withValues(alpha: 0.22)
              : context.cardBgElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? accentColor : context.inputBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.circle_outlined,
              size: 15,
              color: selected ? accentColor : context.textTertiary,
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                color: selected ? context.textPrimary : context.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
