import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../app/language_provider.dart';
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
            const TextSpan(text: ' *', style: TextStyle(color: Colors.red)),
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

// ── School autocomplete ─────────────────────────────────────────────────────

/// Searchable school picker that also accepts a name not on the list.
///
/// The sentinel `__manual__:` option is how a user registers at a school the
/// hardcoded list has never heard of, which for a pilot in Lahore is most of
/// them.
class SchoolSearchField extends StatelessWidget {
  final TextEditingController controller;
  final bool isCustom;
  final void Function(bool) onCustomChanged;
  final Color accentColor;

  const SchoolSearchField({
    super.key,
    required this.controller,
    required this.isCustom,
    required this.onCustomChanged,
    this.accentColor = AppTheme.parentAccent,
  });

  static const _manual = '__manual__:';

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      initialValue: TextEditingValue(text: controller.text),
      optionsBuilder: (textEditingValue) {
        final query = textEditingValue.text.trim().toLowerCase();
        if (query.isEmpty) return const Iterable<String>.empty();
        final matches =
            kSchoolList.where((s) => s.toLowerCase().contains(query)).toList();
        return [...matches, '$_manual${textEditingValue.text.trim()}'];
      },
      displayStringForOption: (option) =>
          option.startsWith(_manual) ? '' : option,
      onSelected: (option) {
        if (option.startsWith(_manual)) {
          controller.text = option.substring(_manual.length);
          onCustomChanged(true);
        } else {
          controller.text = option;
          onCustomChanged(false);
        }
      },
      fieldViewBuilder: (bCtx, fieldCtrl, focusNode, onFieldSubmitted) {
        return TextField(
          controller: fieldCtrl,
          focusNode: focusNode,
          onChanged: (value) => controller.text = value,
          style: TextStyle(color: context.textPrimary, fontSize: 15),
          decoration: InputDecoration(
            hintText: AppStrings.t('search_school_hint'),
            suffixIcon: isCustom
                ? Icon(Icons.edit_note, color: accentColor, size: 20)
                : Icon(Icons.search, color: context.textTertiary, size: 18),
          ),
        );
      },
      optionsViewBuilder: (bCtx, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            color: context.cardBgElevated,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 6),
                shrinkWrap: true,
                children: options.map((option) {
                  final isManual = option.startsWith(_manual);
                  final label = isManual
                      ? '+ Add "${option.substring(_manual.length)}" manually'
                      : option;
                  return InkWell(
                    onTap: () => onSelected(option),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 11,
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          color:
                              isManual ? accentColor : context.textPrimary,
                          fontSize: 14,
                          fontWeight:
                              isManual ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
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
class MapPointField extends StatelessWidget {
  final String placeholder;
  final LatLng? value;
  final ValueChanged<LatLng> onPicked;

  const MapPointField({
    super.key,
    required this.placeholder,
    required this.value,
    required this.onPicked,
  });

  @override
  Widget build(BuildContext context) {
    final label = value == null
        ? placeholder
        : '${value!.latitude.toStringAsFixed(6)}, '
            '${value!.longitude.toStringAsFixed(6)}';

    return GestureDetector(
      onTap: () async {
        final result = await Navigator.of(context).push<LatLng?>(
          MaterialPageRoute(builder: (_) => MapPickerScreen(initial: value)),
        );
        if (result != null) onPicked(result);
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
  final schoolCtrl = TextEditingController();
  String? grade;
  bool isCustomSchool = false;

  ChildFormData({String name = '', String school = '', this.grade}) {
    nameCtrl.text = name;
    schoolCtrl.text = school;
  }

  void dispose() {
    nameCtrl.dispose();
    schoolCtrl.dispose();
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
    return Container(
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
            onChanged: (_) => onChanged(),
            style: TextStyle(color: context.textPrimary, fontSize: 15),
            decoration: InputDecoration(
              hintText: AppStrings.t('childs_name_hint'),
            ),
          ),
          const SizedBox(height: 12),
          FieldLabel(AppStrings.t('grade_level_lbl'), important: true),
          const SizedBox(height: 6),
          ThemedDropdown(
            hint: AppStrings.t('select_level_hint'),
            value: data.grade,
            items: kGradeOptions,
            onChanged: (v) {
              data.grade = v;
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
        ],
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
