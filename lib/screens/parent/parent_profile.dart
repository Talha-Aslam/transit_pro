import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../app/language_provider.dart';
import '../../app/parent_data_service.dart';
import '../../app/profile_service.dart';
import '../../app/subscription_provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_provider.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/image_source_sheet.dart';

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

  bool _boardingAlert = true;
  bool _arrivalAlert = true;
  bool _delayAlert = true;
  bool _smsNotif = false;
  bool _emailNotif = true;

  void _onSubscriptionChanged() => setState(() {});

  @override
  void initState() {
    super.initState();
    SubscriptionProvider.instance.addListener(_onSubscriptionChanged);
    LanguageProvider.instance.addListener(_onLangChanged);
  }

  @override
  void dispose() {
    SubscriptionProvider.instance.removeListener(_onSubscriptionChanged);
    LanguageProvider.instance.removeListener(_onLangChanged);
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
      barrierColor: Colors.black.withOpacity(0.75),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: dialogBg,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.35),
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
                  color: AppTheme.error.withOpacity(0.15),
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
                          color: AppTheme.error.withOpacity(0.22),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.error.withOpacity(0.55),
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
                          AppTheme.parentPurple.withOpacity(0.25),
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
                                ).withOpacity(0.8),
                                borderRadius: BorderRadius.circular(26),
                                border: Border.all(
                                  color: AppTheme.parentPurple.withOpacity(0.5),
                                  width: 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.parentPurple.withOpacity(
                                      0.3,
                                    ),
                                    blurRadius: 24,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: ValueListenableBuilder<File?>(
                                valueListenable:
                                    ProfileService.instance.parentImage,
                                builder: (_, file, __) => ClipRRect(
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
                                color: AppTheme.parentPurple.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: AppTheme.parentPurple.withOpacity(0.3),
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
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.parentPurple.withOpacity(0.1),
                              AppTheme.info.withOpacity(0.05),
                            ],
                          ),
                          borderColor: AppTheme.parentPurple.withOpacity(0.2),
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
                                value: _boardingAlert,
                                onChanged: (v) =>
                                    setState(() => _boardingAlert = v),
                              ),
                              _divider(context),
                              _PrefRow(
                                label: AppStrings.t('arrival_notifs'),
                                desc: AppStrings.t('arrival_notifs_desc'),
                                value: _arrivalAlert,
                                onChanged: (v) =>
                                    setState(() => _arrivalAlert = v),
                              ),
                              _divider(context),
                              _PrefRow(
                                label: AppStrings.t('delay_alerts'),
                                desc: AppStrings.t('delay_alerts_desc'),
                                value: _delayAlert,
                                onChanged: (v) =>
                                    setState(() => _delayAlert = v),
                              ),
                              _divider(context),
                              _PrefRow(
                                label: AppStrings.t('sms_notifs'),
                                desc: AppStrings.t('sms_notifs_desc'),
                                value: _smsNotif,
                                onChanged: (v) => setState(() => _smsNotif = v),
                              ),
                              _divider(context),
                              _PrefRow(
                                label: AppStrings.t('email_notifs'),
                                desc: AppStrings.t('email_notifs_desc'),
                                value: _emailNotif,
                                onChanged: (v) =>
                                    setState(() => _emailNotif = v),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // ── Menu items ────────────────────────────────────
                        GlassCard(
                          child: Column(
                            children: [
                              _MenuItem(
                                icon: '📋',
                                label: AppStrings.t('trip_history'),
                                desc: AppStrings.t('trip_history_desc'),
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
                                isLast: true,
                                onTap: () => context.push('/parent/rate-app'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // ── Theme ─────────────────────────────────────────
                        GlassCard(
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
                              color: AppTheme.error.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppTheme.error.withOpacity(0.25),
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
        border: Border.all(color: AppTheme.parentPurple.withOpacity(0.15)),
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
                          builder: (_, imgs, __) {
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
                        color: AppTheme.parentPurple.withOpacity(0.12),
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
                        color: AppTheme.error.withOpacity(0.10),
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
        children: [
          Container(
            height: 1,
            color: context.surfaceBorder,
            margin: const EdgeInsets.only(bottom: 12),
          ),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.2,
            children: [
              _MiniCard(
                label: 'Bus Number',
                value: c.busNumber.isEmpty ? '—' : c.busNumber,
              ),
              _MiniCard(label: 'Route', value: c.route.isEmpty ? '—' : c.route),
              _MiniCard(label: 'Stop', value: c.stop.isEmpty ? '—' : c.stop),
              _MiniCard(
                label: 'Driver',
                value: c.driver.isEmpty ? '—' : c.driver,
              ),
            ],
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
                        widget.accentColor.withOpacity(0.75),
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

class _BusOption {
  final String busNumber;
  final String driver;
  final String route;
  _BusOption(this.busNumber, this.driver, this.route);
}

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
  _BusOption? _selectedBus;

  final Map<String, List<String>> _institutes = {
    'School': ['Lincoln Elementary', 'Springfield High', 'Beaconhouse'],
    'College': ['City College', 'State College', 'Punjab College'],
    'University': ['University of Lahore', 'FAST NUCES', 'LUMS', 'UET'],
  };

  final List<_BusOption> _allBuses = [
    _BusOption('Bus #42', 'Mike T.', 'Route A (Morning/Evening)'),
    _BusOption('Bus #15', 'Ali H.', 'Route B (Express)'),
    _BusOption('Bus #09', 'John D.', 'Route C (University Line)'),
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialChild.name);
    _gradeCtrl = TextEditingController(text: widget.initialChild.grade);
    _locationCtrl = TextEditingController(text: widget.initialChild.stop)
      ..addListener(() => setState(() {})); // To trigger bus list visibility

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

    if (widget.initialChild.busNumber.isNotEmpty) {
      try {
        _selectedBus = _allBuses.firstWhere(
          (b) => b.busNumber == widget.initialChild.busNumber,
        );
      } catch (_) {}
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
        name: _nameCtrl.text.trim(),
        grade: _gradeCtrl.text.trim(),
        school: _instituteName ?? widget.initialChild.school,
        busNumber: _selectedBus?.busNumber ?? widget.initialChild.busNumber,
        route: _selectedBus?.route ?? widget.initialChild.route,
        stop: _locationCtrl.text.trim(),
        driver: _selectedBus?.driver ?? widget.initialChild.driver,
      ),
    );
    Navigator.pop(context);
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    String hint,
  ) {
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
                      _buildDropdown<String>(
                        label: "Institute Name",
                        value: _instituteName,
                        hint: "Select your $_instituteType",
                        items: availableSchools
                            .map(
                              (s) => DropdownMenuItem(value: s, child: Text(s)),
                            )
                            .toList(),
                        onChanged: (val) {
                          setState(() {
                            _instituteName = val;
                            _selectedBus = null;
                          });
                        },
                      ),
                    _buildTextField(
                      "Current Location (Where you live)",
                      _locationCtrl,
                      "e.g. Oak Street",
                    ),

                    if (showBuses) ...[
                      const Divider(),
                      const SizedBox(height: 10),
                      Text(
                        "Available Buses for this Route",
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ..._allBuses.map((bus) {
                        final isSelected = _selectedBus == bus;
                        return GestureDetector(
                          onTap: () {
                            setState(() => _selectedBus = bus);
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? widget.accentColor.withOpacity(0.15)
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
                                        "${bus.busNumber} • ${bus.route}",
                                        style: TextStyle(
                                          color: context.textPrimary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        "Driver: ${bus.driver}",
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
                        widget.accentColor.withOpacity(0.75),
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
