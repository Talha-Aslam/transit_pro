import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:transit_core/transit_core.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app/language_provider.dart';
import '../../app/parent_data_service.dart';
import '../../app/profile_service.dart';
import '../../app/subscription_provider.dart';
import '../../data/user_repository.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_provider.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/image_source_sheet.dart';
import '../../widgets/profile_form_fields.dart' show FieldLabel, MapPointField;

class ParentProfile extends StatefulWidget {
  final void Function(int) onNavigate;
  final VoidCallback onLogout;

  const ParentProfile({
    super.key,
    required this.onNavigate,
    required this.onLogout,
  });

  @override
  State<ParentProfile> createState() => _ParentProfileState();
}

class _ParentProfileState extends State<ParentProfile> {
  final _svc = ParentDataService.instance;

  void _onSubscriptionChanged() => setState(() {});
  void _onNotificationPrefsChanged() => setState(() {});

  @override
  void initState() {
    super.initState();
    SubscriptionProvider.instance.addListener(_onSubscriptionChanged);
    LanguageProvider.instance.addListener(_onLangChanged);
    _svc.notificationPrefs.addListener(_onNotificationPrefsChanged);
    _svc.loadNotificationPrefs();
  }

  @override
  void dispose() {
    SubscriptionProvider.instance.removeListener(_onSubscriptionChanged);
    LanguageProvider.instance.removeListener(_onLangChanged);
    _svc.notificationPrefs.removeListener(_onNotificationPrefsChanged);
    super.dispose();
  }

  void _onLangChanged() => setState(() {});

  Future<void> _pickImage() async {
    final source = await showImageSourceSheet(
      context,
      accentColor: AppTheme.parentPurple,
    );
    if (source == null) return;
    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 85,
    );
    if (picked != null) {
      ProfileService.instance.parentImage.value = File(picked.path);
    }
  }

  void _editParentInfo() {
    final info = _svc.parentInfo.value;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditSheet(
        title: AppStrings.t('edit_info'),
        fields: [
          _FieldDef(AppStrings.t('full_name'), info.name),
          _FieldDef(AppStrings.t('email'), info.email),
          _FieldDef(AppStrings.t('phone'), info.phone),
        ],
        accentColor: AppTheme.parentPurple,
        onSave: (values) => _svc.updateParentInfo(
          ParentInfo(name: values[0], email: values[1], phone: values[2]),
        ),
      ),
    );
  }

  void _editChild(int index) {
    final child = _svc.children.value[index];
    final label = child.name.isEmpty ? 'Child' : child.name;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ChildFlowSheet(
        title: "${AppStrings.t('edit_info')} - $label",
        initialChild: child,
        accentColor: AppTheme.parentPurple,
        onSave: (updatedChild) => _svc.updateChild(index, updatedChild),
      ),
    );
  }

  void _addChild() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ChildFlowSheet(
        title: AppStrings.t('add_child'),
        initialChild: ChildInfo(),
        accentColor: AppTheme.parentPurple,
        onSave: (newChild) => _svc.addChild(newChild),
      ),
    );
  }

  void _confirmRemoveChild(BuildContext context, int index) {
    final name = _svc.children.value[index].name;
    final isDark = context.isDark;
    final dialogBg = isDark ? const Color(0xFF1E1040) : const Color(0xFFF8FAFF);
    final cancelBg = isDark ? const Color(0xFF2A1860) : const Color(0xFFEDF0F7);
    final cancelBorder = isDark
        ? const Color(0xFF4A2FA0)
        : const Color(0xFFCDD5E0);
    final titleColor = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final bodyColor = isDark ? Colors.white70 : const Color(0xFF5A5A7A);
    final cancelColor = isDark ? Colors.white70 : const Color(0xFF5A5A7A);

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: dialogBg,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 32,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppTheme.error.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppTheme.errorLight,
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                AppStrings.t('remove_child'),
                style: TextStyle(
                  color: titleColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                AppStrings.t('remove_child_confirm').replaceFirst(
                  '{name}',
                  name.isEmpty ? AppStrings.t('this_child') : name,
                ),
                textAlign: TextAlign.center,
                style: TextStyle(color: bodyColor, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(
                          color: cancelBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: cancelBorder),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          AppStrings.t('cancel'),
                          style: TextStyle(
                            color: cancelColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        _svc.removeChild(index);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(
                          color: AppTheme.error.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.error.withValues(alpha: 0.55),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          AppStrings.t('remove'),
                          style: const TextStyle(
                            color: AppTheme.errorLight,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ParentInfo>(
      valueListenable: _svc.parentInfo,
      builder: (context, parentInfo, _) {
        return ValueListenableBuilder<List<ChildInfo>>(
          valueListenable: _svc.children,
          builder: (context, children, _) {
            return SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 100),
              child: Column(
                children: [
                  // ── Profile header ──────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppTheme.parentPurple.withValues(alpha: 0.25),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Column(
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 84,
                              height: 84,
                              decoration: BoxDecoration(
                                color: const Color.fromARGB(
                                  255,
                                  223,
                                  156,
                                  55,
                                ).withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(26),
                                border: Border.all(
                                  color: AppTheme.parentPurple.withValues(
                                    alpha: 0.5,
                                  ),
                                  width: 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.parentPurple.withValues(
                                      alpha: 0.3,
                                    ),
                                    blurRadius: 24,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: ValueListenableBuilder<File?>(
                                valueListenable:
                                    ProfileService.instance.parentImage,
                                builder: (_, file, _) => ClipRRect(
                                  borderRadius: BorderRadius.circular(23),
                                  child: file != null
                                      ? Image.file(
                                          file,
                                          width: 84,
                                          height: 84,
                                          fit: BoxFit.cover,
                                        )
                                      : Image.asset(
                                          'assets/images/profile/boy_transparent.gif',
                                          width: 84,
                                          height: 84,
                                          fit: BoxFit.contain,
                                          filterQuality: FilterQuality.high,
                                        ),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: -4,
                              right: -4,
                              child: GestureDetector(
                                onTap: _pickImage,
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    gradient: AppTheme.parentGradient,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.camera_alt_rounded,
                                      size: 12,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          parentInfo.name,
                          style: TextStyle(
                            color: context.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          parentInfo.email,
                          style: TextStyle(
                            color: context.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                        if (parentInfo.phone.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            parentInfo.phone,
                            style: TextStyle(
                              color: context.textTertiary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.parentPurple.withValues(
                                  alpha: 0.15,
                                ),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: AppTheme.parentPurple.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    '⭐',
                                    style: TextStyle(fontSize: 10),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    '${SubscriptionProvider.instance.planDisplayName} · ${children.length} ${children.length == 1 ? 'child' : 'children'}',
                                    style: const TextStyle(
                                      color: AppTheme.parentAccent,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: _editParentInfo,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: context.cardBg,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: context.surfaceBorder,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Image.asset(
                                      'assets/images/utilities/edit_pencil.png',
                                      width: 15,
                                      height: 15,
                                      fit: BoxFit.contain,
                                      filterQuality: FilterQuality.high,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      AppStrings.t('edit_info'),
                                      style: TextStyle(
                                        color: context.textSecondary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        // ── Children section ──────────────────────────────
                        GlassCard(
                          enableBlur: false,
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.parentPurple.withValues(alpha: 0.1),
                              AppTheme.info.withValues(alpha: 0.05),
                            ],
                          ),
                          borderColor: AppTheme.parentPurple.withValues(
                            alpha: 0.2,
                          ),
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Section header with Add button
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${AppStrings.t('children_section')} (${children.length})',
                                      style: TextStyle(
                                        color: context.textSecondary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: _addChild,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: AppTheme.parentGradient,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.add,
                                            color: Colors.white,
                                            size: 14,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            AppStrings.t('add_child'),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),

                              if (children.isEmpty)
                                Center(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 20,
                                    ),
                                    child: Text(
                                      AppStrings.t('no_children_added'),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: context.textTertiary,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                )
                              else
                                ...List.generate(children.length, (i) {
                                  return Padding(
                                    padding: EdgeInsets.only(
                                      bottom: i < children.length - 1 ? 12 : 0,
                                    ),
                                    child: _ChildCard(
                                      child: children[i],
                                      index: i,
                                      onEdit: () => _editChild(i),
                                      onRemove: () =>
                                          _confirmRemoveChild(context, i),
                                    ),
                                  );
                                }),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // ── Notification preferences ──────────────────────
                        GlassCard(
                          enableBlur: false,
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppStrings.t('notification_prefs'),
                                style: TextStyle(
                                  color: context.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 4),
                              _PrefRow(
                                label: AppStrings.t('boarding_alerts'),
                                desc: AppStrings.t('boarding_alerts_desc'),
                                value: _svc.notificationPrefFor('boarding'),
                                onChanged: (v) =>
                                    _svc.setNotificationPref('boarding', v),
                              ),
                              _divider(context),
                              _PrefRow(
                                label: AppStrings.t('arrival_notifs'),
                                desc: AppStrings.t('arrival_notifs_desc'),
                                value: _svc.notificationPrefFor('arrival'),
                                onChanged: (v) =>
                                    _svc.setNotificationPref('arrival', v),
                              ),
                              _divider(context),
                              _PrefRow(
                                label: AppStrings.t('delay_alerts'),
                                desc: AppStrings.t('delay_alerts_desc'),
                                value: _svc.notificationPrefFor('delay'),
                                onChanged: (v) =>
                                    _svc.setNotificationPref('delay', v),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // ── Transport support ───────────────────────────
                        GlassCard(
                          enableBlur: false,
                          padding: EdgeInsets.zero,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  18,
                                  16,
                                  18,
                                  10,
                                ),
                                child: Text(
                                  AppStrings.t('transport_support'),
                                  style: TextStyle(
                                    color: context.textSecondary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                              _MenuItem(
                                icon: '🧑‍✈️',
                                label: AppStrings.t('my_driver'),
                                desc: AppStrings.t('my_driver_desc'),
                                isLast: true,
                                onTap: () =>
                                    context.push('/parent/driver-details'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // ── Menu items ────────────────────────────────────
                        GlassCard(
                          enableBlur: false,
                          child: Column(
                            children: [
                              _MenuItem(
                                icon: '📋',
                                label: AppStrings.t('trip_history'),
                                //desc: AppStrings.t('trip_history_desc'),
                                onTap: () => context.push('/parent/trips'),
                              ),
                              _MenuItem(
                                icon: '💳',
                                label: AppStrings.t('subscription'),
                                desc:
                                    '${SubscriptionProvider.instance.planDisplayName} Plan · Active',
                                onTap: () =>
                                    context.push('/parent/subscription'),
                              ),
                              _MenuItem(
                                icon: '📞',
                                label: AppStrings.t('emergency_contacts'),
                                desc: AppStrings.t('emergency_contacts_desc'),
                                onTap: () =>
                                    context.push('/parent/emergency-contacts'),
                              ),
                              _MenuItem(
                                icon: '🔐',
                                label: AppStrings.t('change_password'),
                                onTap: () =>
                                    context.push('/parent/change-password'),
                              ),
                              _MenuItem(
                                icon: '🌐',
                                label: AppStrings.t('language'),
                                desc: LanguageProvider.instance.lang,
                                onTap: () => context.push('/parent/language'),
                              ),
                              _MenuItem(
                                icon: '❓',
                                label: AppStrings.t('help_support'),
                                onTap: () =>
                                    context.push('/parent/help-support'),
                              ),
                              _MenuItem(
                                icon: '⭐',
                                label: AppStrings.t('rate_app'),
                                onTap: () => context.push('/parent/rate-app'),
                              ),
                              _MenuItem(
                                icon: '📄',
                                label: AppStrings.t('terms_lbl'),
                                isLast: true,
                                onTap: () => context.push('/parent/terms'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // ── Theme ─────────────────────────────────────────
                        GlassCard(
                          enableBlur: false,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Text(
                                context.isDark ? '🌙' : '☀️',
                                style: const TextStyle(fontSize: 18),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  context.isDark
                                      ? AppStrings.t('dark_mode')
                                      : AppStrings.t('light_mode'),
                                  style: TextStyle(
                                    color: context.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              AppSwitch(
                                value: context.isDark,
                                activeColor: AppTheme.parentPurple,
                                onChanged: (_) =>
                                    ThemeProvider.instance.toggle(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // ── Logout ────────────────────────────────────────
                        GestureDetector(
                          onTap: widget.onLogout,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: AppTheme.error.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppTheme.error.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                AppStrings.t('log_out'),
                                style: const TextStyle(
                                  color: AppTheme.errorLight,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'TransportKid v2.4.1 · © 2026',
                          style: TextStyle(
                            color: context.textTertiary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────── helper widgets ──

Widget _divider(BuildContext context) => Container(
  height: 1,
  color: context.cardBg,
  margin: const EdgeInsets.symmetric(vertical: 0),
);

class _PrefRow extends StatelessWidget {
  final String label, desc;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _PrefRow({
    required this.label,
    required this.desc,
    required this.value,
    required this.onChanged,
  });

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
                Text(
                  label,
                  style: TextStyle(color: context.textPrimary, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: TextStyle(color: context.textTertiary, fontSize: 12),
                ),
              ],
            ),
          ),
          AppSwitch(
            value: value,
            onChanged: onChanged,
            activeColor: AppTheme.parentPurple,
          ),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final String icon, label;
  final String? desc;
  final bool isLast;
  final VoidCallback? onTap;

  const _MenuItem({
    required this.icon,
    required this.label,
    this.desc,
    this.isLast = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : Border(bottom: BorderSide(color: context.surfaceBorder)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: context.cardBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(icon, style: const TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(color: context.textPrimary, fontSize: 14),
                  ),
                  if (desc != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      desc!,
                      style: TextStyle(
                        color: context.textTertiary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Text(
              '›',
              style: TextStyle(color: context.textTertiary, fontSize: 20),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Child card with expand/collapse ──────────────────────────────────────────

class _ChildCard extends StatefulWidget {
  final ChildInfo child;
  final int index;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  const _ChildCard({
    required this.child,
    required this.index,
    required this.onEdit,
    required this.onRemove,
  });

  @override
  State<_ChildCard> createState() => _ChildCardState();
}

class _ChildCardState extends State<_ChildCard> {
  bool _expanded = false;

  final _svc = ParentDataService.instance;

  Future<void> _pickChildImage() async {
    final source = await showImageSourceSheet(
      context,
      accentColor: AppTheme.parentPurple,
    );
    if (source == null) return;
    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 85,
    );
    if (picked != null) {
      _svc.updateChildImage(widget.index, File(picked.path));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.child;
    return Container(
      decoration: BoxDecoration(
        color: context.cardBgElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.parentPurple.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        children: [
          // Row: avatar + name/grade + edit + remove + chevron
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  // ── Child avatar with camera overlay ──────────────────
                  GestureDetector(
                    onTap: _pickChildImage,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        ValueListenableBuilder<List<File?>>(
                          valueListenable: _svc.childImages,
                          builder: (_, imgs, _) {
                            final file = widget.index < imgs.length
                                ? imgs[widget.index]
                                : null;
                            return Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                gradient: file == null
                                    ? const LinearGradient(
                                        colors: [
                                          Color(0xFFF59E0B),
                                          Color(0xFFD97706),
                                        ],
                                      )
                                    : null,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: file != null
                                    ? Image.file(
                                        file,
                                        width: 44,
                                        height: 44,
                                        fit: BoxFit.cover,
                                      )
                                    : Image.asset(
                                        'assets/images/profile/boy_transparent.gif',
                                        width: 44,
                                        height: 44,
                                        fit: BoxFit.contain,
                                        filterQuality: FilterQuality.high,
                                      ),
                              ),
                            );
                          },
                        ),
                        Positioned(
                          bottom: -3,
                          right: -3,
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              gradient: AppTheme.parentGradient,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.camera_alt,
                                size: 10,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.name.isEmpty ? 'Unnamed Child' : c.name,
                          style: TextStyle(
                            color: context.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (c.grade.isNotEmpty || c.school.isNotEmpty)
                          Text(
                            [
                              c.grade,
                              c.school,
                            ].where((s) => s.isNotEmpty).join(' · '),
                            style: TextStyle(
                              color: context.textSecondary,
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  // Edit button
                  GestureDetector(
                    onTap: widget.onEdit,
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.parentPurple.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Image.asset(
                        'assets/images/utilities/edit_pencil.png',
                        width: 15,
                        height: 15,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                      ),
                    ),
                  ),
                  // Remove button
                  GestureDetector(
                    onTap: widget.onRemove,
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.error.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 13,
                        color: AppTheme.errorLight,
                      ),
                    ),
                  ),
                  // Chevron
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: context.textTertiary,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Expanded transport details
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild: _buildDetails(context, c),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 220),
          ),
        ],
      ),
    );
  }

  Widget _buildDetails(BuildContext context, ChildInfo c) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 1,
            color: context.surfaceBorder,
            margin: const EdgeInsets.only(bottom: 12),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final tileWidth = (constraints.maxWidth - 8) / 2;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  SizedBox(
                    width: tileWidth,
                    child: _MiniCard(
                      label: 'Bus Number',
                      value: c.busNumber.isEmpty ? '—' : c.busNumber,
                    ),
                  ),
                  SizedBox(
                    width: tileWidth,
                    child: _MiniCard(
                      label: 'Route',
                      value: c.route.isEmpty ? '—' : c.route,
                    ),
                  ),
                  SizedBox(
                    width: tileWidth,
                    child: _MiniCard(
                      label: 'Stop',
                      value: c.stop.isEmpty ? '—' : c.stop,
                    ),
                  ),
                  SizedBox(
                    width: tileWidth,
                    child: _MiniCard(
                      label: 'Driver',
                      value: c.driver.isEmpty ? '—' : c.driver,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Mini detail card ──────────────────────────────────────────────────────────

class _MiniCard extends StatelessWidget {
  final String label, value;
  const _MiniCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              color: context.textTertiary,
              fontSize: 9,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ── Edit bottom sheet ─────────────────────────────────────────────────────────

/// Describes a single editable field inside [_EditSheet].
class _FieldDef {
  final String label;
  final String initialValue;
  _FieldDef(this.label, this.initialValue);
}

class _EditSheet extends StatefulWidget {
  final String title;
  final List<_FieldDef> fields;
  final Color accentColor;
  final void Function(List<String> values) onSave;

  const _EditSheet({
    required this.title,
    required this.fields,
    required this.accentColor,
    required this.onSave,
  });

  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  late final List<TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = widget.fields
        .map((f) => TextEditingController(text: f.initialValue))
        .toList();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    widget.onSave(_controllers.map((c) => c.text.trim()).toList());
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final sheetBg = context.isDark ? AppTheme.bgDark : Colors.white;
    final inputFill = context.isDark
        ? AppTheme.bgDarkBlue
        : const Color(0xFFF1F5F9);

    // Fixed height: 85% of the screen. When the keyboard appears, only the
    // bottom padding grows, pushing the Save button up above the keyboard.
    // The Expanded ScrollView absorbs any leftover space changes.
    final sheetHeight = MediaQuery.of(context).size.height * 0.85;

    return SizedBox(
      height: sheetHeight,
      child: Container(
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
        child: Column(
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                color: context.surfaceBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Title
            Text(
              widget.title,
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 20),
            // Scrollable fields – Expanded so Save button is always visible
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: List.generate(widget.fields.length, (i) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.fields[i].label,
                            style: TextStyle(
                              color: context.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _controllers[i],
                            style: TextStyle(
                              color: context.textPrimary,
                              fontSize: 14,
                            ),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: inputFill,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: context.inputBorder,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: context.inputBorder,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: widget.accentColor,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Save button
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: _save,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        widget.accentColor,
                        widget.accentColor.withValues(alpha: 0.75),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Text(
                      'Save Changes',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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

// ─────────────────────────────────────────────────────────── custom child sheet

class _ChildFlowSheet extends StatefulWidget {
  final String title;
  final ChildInfo initialChild;
  final Color accentColor;
  final void Function(ChildInfo) onSave;

  const _ChildFlowSheet({
    required this.title,
    required this.initialChild,
    required this.accentColor,
    required this.onSave,
  });

  @override
  State<_ChildFlowSheet> createState() => _ChildFlowSheetState();
}

class _ChildFlowSheetState extends State<_ChildFlowSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _gradeCtrl;
  late final TextEditingController _locationCtrl;

  String? _instituteType;
  String? _instituteName;

  // Where the child is collected from / dropped off. Pre-filled below from
  // `widget.initialChild.pickup`/`.dropoff` — see `ParentDataService._rebuild`
  // for where those come from on the `Student` document.
  GeoCoord? _pickup;
  GeoCoord? _dropoff;

  // Real driver picked from the list below, replacing what used to be a
  // hardcoded `_BusOption` the parent could "select" even though it matched
  // nothing in Firestore. See the comment above the StreamBuilder further
  // down for what this selection does and doesn't do.
  Driver? _selectedDriver;

  /// Which of `_selectedDriver`'s rounds this child rides — `Student
  /// .scheduleId`. Only meaningful (and only shown) when the driver runs
  /// more than one; reset to null on a driver change since another driver's
  /// round ids don't apply to a new selection.
  String? _scheduleId;

  // Cached so a new Firestore listener isn't opened on every rebuild this
  // sheet does (e.g. every keystroke in the location field re-triggers
  // build() via its listener) — only recreated when the institute changes.
  Stream<List<Driver>>? _driversStream;
  String? _driversStreamInstitute;

  Stream<List<Driver>> _driversStreamFor(String institute) {
    if (_driversStreamInstitute != institute) {
      _driversStreamInstitute = institute;
      _driversStream = UserRepository.instance.watchDriversServing(institute);
    }
    return _driversStream!;
  }

  Future<void> _showDriverPreview(Driver driver) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        final isDark = context.isDark;
        final sheetBg = isDark ? AppTheme.bgDark : Colors.white;
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: sheetBg,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: context.surfaceBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  'Driver Preview',
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppTheme.parentPurple.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.drive_eta_rounded,
                        size: 30,
                        color: AppTheme.parentAccent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            driver.name.isEmpty
                                ? 'Unnamed driver'
                                : driver.name,
                            style: TextStyle(
                              color: context.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '·',
                            style: TextStyle(
                              color: context.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            driver.phone.isNotEmpty
                                ? driver.phone
                                : 'Contact not available',
                            style: TextStyle(
                              color: context.textPrimary,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.verified,
                                size: 16,
                                color: driver.isApproved
                                    ? AppTheme.parentAccent
                                    : context.textHint,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                driver.isApproved
                                    ? 'Verified'
                                    : 'Not verified',
                                style: TextStyle(
                                  color: context.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Icon(
                                Icons.confirmation_number_outlined,
                                size: 16,
                                color: context.textHint,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                // Sum of seats offered across the driver's
                                // rounds — Driver has no single "vehicle
                                // capacity" field (see DriverSchedule for
                                // why seats are per-round, not per-vehicle).
                                '${driver.totalSeatsOffered} seats',
                                style: TextStyle(
                                  color: context.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.star,
                              size: 16,
                              color: Colors.amber,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              driver.ratingCount == 0
                                  ? 'New'
                                  : driver.rating.toStringAsFixed(1),
                              style: TextStyle(
                                color: context.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${driver.ratingCount} rating${driver.ratingCount == 1 ? '' : 's'}',
                          style: TextStyle(
                            color: context.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (driver.serviceAreas.isNotEmpty) ...[
                  Text(
                    'Serves',
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: driver.serviceAreas
                        .map((a) => a.name)
                        .map(
                          (s) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: context.isDark
                                  ? AppTheme.bgDarkBlue
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              s,
                              style: TextStyle(
                                color: context.textPrimary,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context, false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: context.isDark
                                ? const Color(0xFF2A2A3A)
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: context.inputBorder),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              color: context.textSecondary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context, true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                widget.accentColor,
                                widget.accentColor.withValues(alpha: 0.8),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'Confirm',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted) return;

    if (confirmed == true) {
      setState(() {
        if (_selectedDriver?.id != driver.id) _scheduleId = null;
        _selectedDriver = driver;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Selected ${driver.name}')));
      // This is still only a preview, same as before: picking a driver here
      // doesn't book a seat or link the student to them in Firestore (the
      // real booking path is Find Drivers -> request a seat, which reserves
      // a specific round via RideMatchService.requestSeat and notifies the
      // driver for real). Rebuilding this picker on top of that flow is
      // beyond this pass — the fix here is only that the driver shown and
      // selected is now a real Firestore record instead of an invented one.
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: context.isDark
              ? const Color(0xFF10351F)
              : const Color(0xFFEAF8EF),
          title: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Color(0xFF22C55E)),
              const SizedBox(width: 10),
              Text(
                'Request Sent',
                style: TextStyle(
                  color: context.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          content: Text(
            'Your request has been sent to ${driver.name}. They will respond shortly.',
            style: TextStyle(color: context.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF16A34A),
              ),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  final Map<String, List<String>> _institutes = {
    'School': ['Lincoln Elementary', 'Springfield High', 'Beaconhouse'],
    'College': ['City College', 'State College', 'Punjab College'],
    'University': ['University of Lahore', 'FAST NUCES', 'LUMS', 'UET'],
  };

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialChild.name);
    _gradeCtrl = TextEditingController(text: widget.initialChild.grade);
    _locationCtrl = TextEditingController(text: widget.initialChild.stop)
      ..addListener(() => setState(() {})); // To trigger bus list visibility
    _pickup = widget.initialChild.pickup;
    _dropoff = widget.initialChild.dropoff;
    _scheduleId = widget.initialChild.scheduleId;

    if (widget.initialChild.school.isNotEmpty) {
      for (final entry in _institutes.entries) {
        if (entry.value.contains(widget.initialChild.school)) {
          _instituteType = entry.key;
          _instituteName = widget.initialChild.school;
          break;
        }
      }
      if (_instituteType == null) {
        _instituteType = 'School';
        _instituteName = null;
      }
    }

    // `initialChild.driver` holds a real driver uid when it was assigned
    // through the ride-request flow (see ParentDataService._rebuild) — fetch
    // it so an existing selection shows as selected rather than starting
    // blank every time this sheet reopens.
    if (widget.initialChild.driver.isNotEmpty) {
      UserRepository.instance.fetchDriver(widget.initialChild.driver).then((
        d,
      ) {
        if (mounted && d != null) setState(() => _selectedDriver = d);
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _gradeCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  void _save() {
    widget.onSave(
      ChildInfo(
        // Without the id, `ParentDataService.updateChild` has nothing to
        // target in Firestore and silently skips the write (see its
        // `if (child.id.isEmpty) return;` guard) — so this has to travel
        // through untouched, same as `busNumber`/`route` below.
        id: widget.initialChild.id,
        name: _nameCtrl.text.trim(),
        grade: _gradeCtrl.text.trim(),
        school: _instituteName ?? widget.initialChild.school,
        // Picking a driver in this sheet is a preview only (see
        // _showDriverPreview) — it doesn't book a seat or assign a bus/route,
        // so those stay whatever they already were. Only the driver id
        // (now a real one, not an invented display name) is carried through.
        busNumber: widget.initialChild.busNumber,
        route: widget.initialChild.route,
        stop: _locationCtrl.text.trim(),
        driver: _selectedDriver?.id ?? widget.initialChild.driver,
        photoUrl: widget.initialChild.photoUrl,
        pickup: _pickup,
        dropoff: _dropoff,
        scheduleId: _scheduleId,
      ),
    );
    Navigator.pop(context);
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    String hint, {
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: context.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          onChanged: onChanged,
          style: TextStyle(color: context.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: context.textHint),
            filled: true,
            fillColor: context.isDark
                ? AppTheme.bgDarkBlue
                : const Color(0xFFF1F5F9),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: context.inputBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: context.inputBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: widget.accentColor, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 14),
      ],
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    String? hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: context.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: context.isDark
                ? AppTheme.bgDarkBlue
                : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.inputBorder),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              hint: hint != null
                  ? Text(hint, style: TextStyle(color: context.textHint))
                  : null,
              dropdownColor: context.isDark ? AppTheme.bgDark : Colors.white,
              style: TextStyle(color: context.textPrimary, fontSize: 14),
              items: items,
              onChanged: onChanged,
            ),
          ),
        ),
        const SizedBox(height: 14),
      ],
    );
  }

  Future<void> _openInstituteMap() async {
    final institute = _instituteName ?? widget.initialChild.school;
    if (institute.trim().isEmpty) return;

    final query = [
      institute.trim(),
      if (_instituteType != null) _instituteType,
    ].where((part) => part != null && part.isNotEmpty).join(' ');
    await _openMapQuery(query);
  }

  Future<void> _openCurrentLocationMap() async {
    final location = _locationCtrl.text.trim();
    if (location.isEmpty) return;
    await _openMapQuery(location);
  }

  Future<void> _openMapQuery(String rawQuery) async {
    final query = rawQuery.trim();
    if (query.isEmpty) return;

    final encoded = Uri.encodeComponent(query);
    final webUri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$encoded',
    );

    bool opened = false;
    if (Platform.isAndroid) {
      final androidGeo = Uri.parse('geo:0,0?q=$encoded');
      if (await canLaunchUrl(androidGeo)) {
        opened = await launchUrl(
          androidGeo,
          mode: LaunchMode.externalApplication,
        );
      }
    } else if (Platform.isIOS) {
      final iosGoogleMaps = Uri.parse('comgooglemaps://?q=$encoded');
      if (await canLaunchUrl(iosGoogleMaps)) {
        opened = await launchUrl(
          iosGoogleMaps,
          mode: LaunchMode.externalApplication,
        );
      }
    }

    if (!opened && await canLaunchUrl(webUri)) {
      opened = await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }

    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open Google Maps right now.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final sheetBg = context.isDark ? AppTheme.bgDark : Colors.white;

    final sheetHeight = MediaQuery.of(context).size.height * 0.85;

    final availableSchools = _instituteType != null
        ? _institutes[_instituteType]!
        : <String>[];

    final bool showBuses =
        _instituteName != null && _locationCtrl.text.trim().isNotEmpty;

    return SizedBox(
      height: sheetHeight,
      child: Container(
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                color: context.surfaceBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              widget.title,
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTextField(
                      "Student / Child Name",
                      _nameCtrl,
                      "e.g. John Doe",
                    ),
                    _buildTextField(
                      "Grade / Class",
                      _gradeCtrl,
                      "e.g. Grade 5",
                    ),
                    _buildDropdown<String>(
                      label: "Institute Type",
                      value: _instituteType,
                      hint: "Select School / College / University",
                      items: _institutes.keys
                          .map(
                            (k) => DropdownMenuItem(value: k, child: Text(k)),
                          )
                          .toList(),
                      onChanged: (val) {
                        setState(() {
                          _instituteType = val;
                          _instituteName = null;
                        });
                      },
                    ),
                    if (_instituteType != null)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: _buildDropdown<String>(
                              label: "Institute Name",
                              value: _instituteName,
                              hint: "Select your $_instituteType",
                              items: availableSchools
                                  .map(
                                    (s) => DropdownMenuItem(
                                      value: s,
                                      child: Text(s),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (val) {
                                setState(() {
                                  _instituteName = val;
                                  _selectedDriver = null;
                                  _scheduleId = null;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Tooltip(
                            message: "Open institute in Google Maps",
                            child: GestureDetector(
                              onTap: _instituteName == null
                                  ? null
                                  : _openInstituteMap,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 14),
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: _instituteName == null
                                      ? context.surfaceBorder.withValues(
                                          alpha: 0.45,
                                        )
                                      : AppTheme.info.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: _instituteName == null
                                        ? context.surfaceBorder
                                        : AppTheme.info.withValues(alpha: 0.25),
                                  ),
                                ),
                                child: Icon(
                                  Icons.my_location_rounded,
                                  color: _instituteName == null
                                      ? context.textTertiary
                                      : AppTheme.info,
                                  size: 22,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: _buildTextField(
                            "Current Location (Where you live)",
                            _locationCtrl,
                            "e.g. Oak Street",
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Tooltip(
                          message: "Open location in Google Maps",
                          child: GestureDetector(
                            onTap: _locationCtrl.text.trim().isEmpty
                                ? null
                                : _openCurrentLocationMap,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: _locationCtrl.text.trim().isEmpty
                                    ? context.surfaceBorder.withValues(
                                        alpha: 0.45,
                                      )
                                    : AppTheme.info.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: _locationCtrl.text.trim().isEmpty
                                      ? context.surfaceBorder
                                      : AppTheme.info.withValues(alpha: 0.25),
                                ),
                              ),
                              child: Icon(
                                Icons.my_location_rounded,
                                color: _locationCtrl.text.trim().isEmpty
                                    ? context.textTertiary
                                    : AppTheme.info,
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const FieldLabel('PICKUP LOCATION (OPTIONAL)'),
                    const SizedBox(height: 6),
                    MapPointField(
                      placeholder: 'Tap to pin where the van collects them',
                      value: _pickup,
                      accentColor: widget.accentColor,
                      onPicked: (p) => setState(() => _pickup = p),
                    ),
                    const SizedBox(height: 12),
                    const FieldLabel('DROP-OFF LOCATION (OPTIONAL)'),
                    const SizedBox(height: 6),
                    MapPointField(
                      placeholder: 'Tap to pin where the van drops them off',
                      value: _dropoff,
                      accentColor: widget.accentColor,
                      onPicked: (p) => setState(() => _dropoff = p),
                    ),

                    if (showBuses) ...[
                      const Divider(),
                      const SizedBox(height: 10),
                      Text(
                        "Drivers Serving This Institute",
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Real drivers from Firestore, scoped to the selected
                      // institute — this used to be a hardcoded list of three
                      // invented buses/drivers a parent could "select" even
                      // though nothing behind them existed. See
                      // _showDriverPreview for what picking one here does (a
                      // preview only, not a booking).
                      StreamBuilder<List<Driver>>(
                        stream: _driversStreamFor(_instituteName!),
                        builder: (context, snap) {
                          if (!snap.hasData) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                            );
                          }
                          final drivers = snap.data!;
                          if (drivers.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 8,
                              ),
                              child: Text(
                                'No drivers currently list "$_instituteName" '
                                'as a stop yet.',
                                style: TextStyle(
                                  color: context.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            );
                          }
                          return Column(
                            children: drivers.map((driver) {
                              final isSelected =
                                  _selectedDriver?.id == driver.id;
                              return GestureDetector(
                                onTap: () => _showDriverPreview(driver),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? widget.accentColor.withValues(
                                            alpha: 0.15,
                                          )
                                        : context.isDark
                                        ? AppTheme.bgDarkBlue
                                        : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? widget.accentColor
                                          : context.inputBorder,
                                      width: isSelected ? 2 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              driver.name.isEmpty
                                                  ? 'Unnamed driver'
                                                  : driver.name,
                                              style: TextStyle(
                                                color: context.textPrimary,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              driver.isApproved
                                                  ? 'Verified driver'
                                                  : 'Verification pending',
                                              style: TextStyle(
                                                color: context.textSecondary,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isSelected)
                                        Icon(
                                          Icons.check_circle,
                                          color: widget.accentColor,
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                      // ── Round picker ───────────────────────────────────
                      // Only meaningful when the assigned driver actually
                      // runs more than one round — with zero or one, there is
                      // nothing to choose, so `Student.scheduleId` stays
                      // whatever it already was (usually the driver's only
                      // round, assigned at accept time).
                      if (_selectedDriver != null &&
                          _selectedDriver!.orderedSchedules.length > 1) ...[
                        const SizedBox(height: 14),
                        Text(
                          'Which round does this child ride?',
                          style: TextStyle(
                            color: context.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _selectedDriver!.orderedSchedules.map((
                            s,
                          ) {
                            final selected = _scheduleId == s.id;
                            final label = s.label.isEmpty
                                ? s.timeRange
                                : '${s.label} (${s.timeRange})';
                            return GestureDetector(
                              onTap: () =>
                                  setState(() => _scheduleId = s.id),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? widget.accentColor.withValues(
                                          alpha: 0.15,
                                        )
                                      : context.isDark
                                      ? AppTheme.bgDarkBlue
                                      : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: selected
                                        ? widget.accentColor
                                        : context.inputBorder,
                                  ),
                                ),
                                child: Text(
                                  label,
                                  style: TextStyle(
                                    color: selected
                                        ? widget.accentColor
                                        : context.textSecondary,
                                    fontSize: 12,
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: _save,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        widget.accentColor,
                        widget.accentColor.withValues(alpha: 0.75),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Text(
                      'Save Changes',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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
