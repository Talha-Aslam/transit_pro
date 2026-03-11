import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/language_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

class EmergencyContactsScreen extends StatefulWidget {
  final Color accentColor;
  const EmergencyContactsScreen({
    super.key,
    this.accentColor = AppTheme.parentPurple,
  });

  @override
  State<EmergencyContactsScreen> createState() =>
      _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  final List<_Contact> _contacts = [
    _Contact(
      name: 'Sarah Johnson',
      relation: 'Mother',
      phone: '+92 300 1234567',
    ),
    _Contact(
      name: 'Ahmed Johnson',
      relation: 'Father',
      phone: '+92 321 7654321',
    ),
  ];

  @override
  void initState() {
    super.initState();
    LanguageProvider.instance.addListener(_onLangChanged);
  }

  @override
  void dispose() {
    LanguageProvider.instance.removeListener(_onLangChanged);
    super.dispose();
  }

  void _onLangChanged() => setState(() {});

  void _showAddSheet({_Contact? existing, int? index}) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final relCtrl = TextEditingController(text: existing?.relation ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        final bottom = MediaQuery.of(context).viewInsets.bottom;
        return Container(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
          decoration: BoxDecoration(
            color: AppTheme.bgDark,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                existing == null
                    ? AppStrings.t('add_contact')
                    : AppStrings.t('edit_contact'),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              _buildField(
                nameCtrl,
                AppStrings.t('full_name'),
                Icons.person_outline,
              ),
              const SizedBox(height: 10),
              _buildField(
                relCtrl,
                AppStrings.t('relation'),
                Icons.family_restroom,
              ),
              const SizedBox(height: 10),
              _buildField(
                phoneCtrl,
                AppStrings.t('phone_number'),
                Icons.phone_outlined,
                type: TextInputType.phone,
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Text(
                            AppStrings.t('cancel'),
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        final name = nameCtrl.text.trim();
                        final rel = relCtrl.text.trim();
                        final phone = phoneCtrl.text.trim();
                        if (name.isEmpty || phone.isEmpty) return;
                        setState(() {
                          final c = _Contact(
                            name: name,
                            relation: rel,
                            phone: phone,
                          );
                          if (existing != null && index != null) {
                            _contacts[index] = c;
                          } else {
                            _contacts.add(c);
                          }
                        });
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          gradient: AppTheme.parentGradient,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Text(
                            existing == null
                                ? AppStrings.t('add_contact')
                                : AppStrings.t('save'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildField(
    TextEditingController ctrl,
    String hint,
    IconData icon, {
    TextInputType type = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgDarkBlue,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: TextField(
        controller: ctrl,
        keyboardType: type,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white38),
          prefixIcon: Icon(icon, color: Colors.white38, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  void _confirmDelete(int index) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          AppStrings.t('remove_contact'),
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          '${AppStrings.t('remove_contact')}: ${_contacts[index].name}?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              AppStrings.t('cancel'),
              style: const TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() => _contacts.removeAt(index));
              Navigator.pop(context);
            },
            child: Text(
              AppStrings.t('remove'),
              style: const TextStyle(color: AppTheme.error),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: context.scaffoldBg,
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      widget.accentColor.withOpacity(0.2),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: context.cardBgElevated,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: context.inputBorder),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.arrow_back,
                            color: context.textPrimary,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        AppStrings.t('emergency_contacts_title'),
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _showAddSheet(),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          gradient: AppTheme.parentGradient,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Icon(Icons.add, color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: _contacts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('📞', style: TextStyle(fontSize: 48)),
                            const SizedBox(height: 12),
                            Text(
                              AppStrings.t('no_emergency_contacts'),
                              style: TextStyle(color: context.textSecondary),
                            ),
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: () => _showAddSheet(),
                              child: Text(
                                AppStrings.t('add_one_now'),
                                style: TextStyle(
                                  color: widget.accentColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _contacts.length,
                        itemBuilder: (_, i) {
                          final c = _contacts[i];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: GlassCard(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    width: 46,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      gradient: AppTheme.parentGradient,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Center(
                                      child: Text(
                                        c.name.isNotEmpty
                                            ? c.name[0].toUpperCase()
                                            : '?',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          c.name,
                                          style: TextStyle(
                                            color: context.textPrimary,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          c.relation.isNotEmpty
                                              ? c.relation
                                              : AppStrings.t(
                                                  'emergency_contact_fallback',
                                                ),
                                          style: TextStyle(
                                            color: context.textSecondary,
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          c.phone,
                                          style: TextStyle(
                                            color: widget.accentColor,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      GestureDetector(
                                        onTap: () => _showAddSheet(
                                          existing: c,
                                          index: i,
                                        ),
                                        child: Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            color: AppTheme.info.withOpacity(
                                              0.12,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: const Center(
                                            child: Icon(
                                              Icons.edit_outlined,
                                              size: 17,
                                              color: AppTheme.info,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      GestureDetector(
                                        onTap: () => _confirmDelete(i),
                                        child: Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            color: AppTheme.error.withOpacity(
                                              0.12,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: const Center(
                                            child: Icon(
                                              Icons.delete_outline,
                                              size: 17,
                                              color: AppTheme.error,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Contact {
  final String name, relation, phone;
  const _Contact({
    required this.name,
    required this.relation,
    required this.phone,
  });
}
