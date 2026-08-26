import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:transit_core/transit_core.dart';

import '../../app/language_provider.dart';
import '../../app/session_service.dart';
import '../../data/user_repository.dart';
import '../../services/cloudinary_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

const _kDocMeta = <DocumentType, (String icon, String title, String hint)>{
  DocumentType.drivingLicense: (
    '🪪',
    'Driving License',
    'Front & back photo of your driving license',
  ),
  DocumentType.vehicleRegistration: (
    '🚌',
    'Vehicle Registration',
    'Photo of vehicle registration certificate',
  ),
  DocumentType.insuranceCertificate: (
    '🛡️',
    'Insurance Certificate',
    'Upload your current insurance document',
  ),
  DocumentType.routePermit: (
    '📋',
    'Route Permit',
    'Photo of the route permit issued by authority',
  ),
  DocumentType.medicalFitness: (
    '🩺',
    'Medical Fitness Certificate',
    'Medical fitness certificate from a registered doctor',
  ),
  DocumentType.schoolContract: (
    '🏫',
    'School Contract',
    'Signed contract document from the school',
  ),
};

class DriverDocumentsScreen extends StatefulWidget {
  const DriverDocumentsScreen({super.key});

  @override
  State<DriverDocumentsScreen> createState() => _DriverDocumentsScreenState();
}

class _DriverDocumentsScreenState extends State<DriverDocumentsScreen> {
  final _picker = ImagePicker();
  final _repo = UserRepository.instance;

  /// Every document this driver has ever submitted, across every re-upload
  /// attempt — a driver can only `create` new rows, never edit an old one's
  /// status (see `firestore.rules`), so this can hold several per type.
  List<DriverDocument> _all = [];
  bool _loaded = false;
  final _uploading = <DocumentType>{};

  @override
  void initState() {
    super.initState();
    LanguageProvider.instance.addListener(_rebuild);
    final driverId = SessionService.instance.uid;
    if (driverId != null) {
      _repo.watchDriverDocuments(driverId).listen(
        (docs) {
          if (!mounted) return;
          setState(() {
            _all = docs;
            _loaded = true;
          });
        },
        onError: (Object e) => debugPrint('driver documents stream: $e'),
      );
    }
  }

  @override
  void dispose() {
    LanguageProvider.instance.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  /// The most recent submission per type — an old rejected/replaced attempt
  /// must not shadow whatever the driver uploaded after it.
  DriverDocument? _latest(DocumentType type) {
    DriverDocument? best;
    for (final d in _all) {
      if (d.type != type) continue;
      if (best == null ||
          (d.uploadedAt ?? DateTime(0)).isAfter(best.uploadedAt ?? DateTime(0))) {
        best = d;
      }
    }
    return best;
  }

  bool get _isApproved => SessionService.instance.driver.value?.isApproved ?? false;

  int get _verifiedCount => _kDocMeta.keys
      .where((t) => _latest(t)?.status == DocumentStatus.verified)
      .length;

  int get _pendingCount => _kDocMeta.keys
      .where((t) => _latest(t)?.status == DocumentStatus.pending)
      .length;

  int get _missingCount => _kDocMeta.keys
      .where((t) {
        final d = _latest(t);
        return d == null || d.status == DocumentStatus.rejected;
      })
      .length;

  Future<void> _pickFile(DocumentType type) async {
    final meta = _kDocMeta[type]!;
    final choice = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _PickerSheet(docTitle: meta.$2),
    );
    if (choice == null) return;

    final picked = await _picker.pickImage(source: choice, imageQuality: 85);
    if (picked == null) return;

    final driverId = SessionService.instance.uid;
    if (driverId == null) return;

    setState(() => _uploading.add(type));
    try {
      if (!CloudinaryService.instance.isConfigured) {
        throw const UploadException(
          'File upload is not configured for this app yet.',
        );
      }
      final result = await CloudinaryService.instance.uploadDriverDocument(
        File(picked.path),
        driverId,
        type.name,
      );
      await _repo.submitDriverDocument(
        DriverDocument(
          id: '',
          driverId: driverId,
          type: type,
          status: DocumentStatus.pending,
          fileUrl: result.secureUrl,
          publicId: result.publicId,
          fileName: picked.name,
        ),
      );
      if (mounted) {
        _showSnack('${meta.$2} uploaded — awaiting admin verification.');
      }
    } catch (e) {
      if (mounted) _showSnack('Upload failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _uploading.remove(type));
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: isError ? AppTheme.error : AppTheme.driverCyan,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
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
              // ── Header ────────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppTheme.driverCyan.withValues(alpha: 0.2),
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
                    const SizedBox(width: 14),
                    Text(
                      AppStrings.t('documents_license'),
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: !_loaded
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        child: Column(
                          children: [
                            // ── Eligibility banner ─────────────────────────
                            // Driven by the real, admin-set account status —
                            // not by whether every document individually
                            // shows "verified" here, since an admin's review
                            // process is the actual source of truth.
                            _EligibilityBanner(
                              isApproved: _isApproved,
                              missingCount: _missingCount,
                              pendingCount: _pendingCount,
                            ),
                            const SizedBox(height: 12),

                            // ── Summary card ────────────────────────────────
                            GlassCard(
                              gradient: LinearGradient(
                                colors: [
                                  AppTheme.driverCyan.withValues(alpha: 0.15),
                                  AppTheme.driverTeal.withValues(alpha: 0.05),
                                ],
                              ),
                              borderColor: AppTheme.driverCyan.withValues(
                                alpha: 0.3,
                              ),
                              padding: const EdgeInsets.all(20),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  _SummaryPill(
                                    icon: '✅',
                                    value: '$_verifiedCount',
                                    label: 'Verified',
                                    color: AppTheme.successLight,
                                  ),
                                  Container(
                                    width: 1,
                                    height: 40,
                                    color: context.cardBgElevated,
                                  ),
                                  _SummaryPill(
                                    icon: '🕐',
                                    value: '$_pendingCount',
                                    label: 'Pending',
                                    color: AppTheme.warningLight,
                                  ),
                                  Container(
                                    width: 1,
                                    height: 40,
                                    color: context.cardBgElevated,
                                  ),
                                  _SummaryPill(
                                    icon: '📤',
                                    value: '$_missingCount',
                                    label: 'Upload',
                                    color: AppTheme.driverAccent,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // ── Document cards ──────────────────────────────
                            ..._kDocMeta.entries.map((entry) {
                              final type = entry.key;
                              final meta = entry.value;
                              final doc = _latest(type);
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _DocCard(
                                  icon: meta.$1,
                                  title: meta.$2,
                                  hint: meta.$3,
                                  status: doc?.status ?? DocumentStatus.notUploaded,
                                  fileName: doc?.fileName,
                                  uploading: _uploading.contains(type),
                                  rejectionReason: doc?.rejectionReason,
                                  onUpload: () => _pickFile(type),
                                ),
                              );
                            }),
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
}

// ─── Eligibility Banner ───────────────────────────────────────────────────────
class _EligibilityBanner extends StatelessWidget {
  final bool isApproved;
  final int missingCount;
  final int pendingCount;

  const _EligibilityBanner({
    required this.isApproved,
    required this.missingCount,
    required this.pendingCount,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color border;
    final Color iconBg;
    final String icon;
    final String title;
    final String subtitle;

    if (isApproved) {
      bg = AppTheme.success.withValues(alpha: 0.12);
      border = AppTheme.success.withValues(alpha: 0.4);
      iconBg = AppTheme.success.withValues(alpha: 0.2);
      icon = '✅';
      title = 'Eligible for Rides';
      subtitle = 'Your account is verified. You are cleared to accept rides.';
    } else if (missingCount > 0) {
      bg = AppTheme.error.withValues(alpha: 0.1);
      border = AppTheme.error.withValues(alpha: 0.35);
      iconBg = AppTheme.error.withValues(alpha: 0.15);
      icon = '🚫';
      title = 'Not Eligible for Rides';
      subtitle =
          '$missingCount document${missingCount > 1 ? 's' : ''} still need to be uploaded.';
    } else {
      bg = AppTheme.warning.withValues(alpha: 0.1);
      border = AppTheme.warning.withValues(alpha: 0.35);
      iconBg = AppTheme.warning.withValues(alpha: 0.15);
      icon = '🕐';
      title = 'Verification Pending';
      subtitle = pendingCount > 0
          ? '$pendingCount document${pendingCount > 1 ? 's are' : ' is'} under review by admin.'
          : 'Your account is awaiting admin verification.';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Center(
              child: Text(icon, style: const TextStyle(fontSize: 20)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(color: context.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Document Card ────────────────────────────────────────────────────────────
class _DocCard extends StatelessWidget {
  final String icon;
  final String title;
  final String hint;
  final DocumentStatus status;
  final String? fileName;
  final bool uploading;
  final String? rejectionReason;
  final VoidCallback onUpload;

  const _DocCard({
    required this.icon,
    required this.title,
    required this.hint,
    required this.status,
    required this.fileName,
    required this.uploading,
    required this.rejectionReason,
    required this.onUpload,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      // Built once per document via a fixed-length map — a repeated list
      // item, so the blur pass would otherwise repeat for every visible card
      // on every scroll frame.
      enableBlur: false,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.driverCyan.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(icon, style: const TextStyle(fontSize: 22)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hint,
                      style: TextStyle(
                        color: context.textTertiary,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _StatusBadge(status: status),
            ],
          ),

          // State-specific content
          if (uploading) ...[
            const SizedBox(height: 12),
            const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ] else if (status == DocumentStatus.notUploaded) ...[
            const SizedBox(height: 12),
            _UploadButton(onTap: onUpload),
          ] else if (status == DocumentStatus.pending) ...[
            const SizedBox(height: 12),
            _PendingPreview(
              fileName: fileName ?? 'Document',
              onReupload: onUpload,
            ),
          ] else if (status == DocumentStatus.rejected) ...[
            const SizedBox(height: 12),
            _RejectedRow(reason: rejectionReason, onReupload: onUpload),
          ],
        ],
      ),
    );
  }
}

// ─── Upload button ────────────────────────────────────────────────────────────
class _UploadButton extends StatelessWidget {
  final VoidCallback onTap;
  const _UploadButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: AppTheme.driverCyan.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.driverCyan.withValues(alpha: 0.4),
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.upload_rounded, color: AppTheme.driverCyan, size: 18),
            const SizedBox(width: 8),
            Text(
              'Upload Document',
              style: TextStyle(
                color: AppTheme.driverCyan,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Pending preview ──────────────────────────────────────────────────────────
class _PendingPreview extends StatelessWidget {
  final String fileName;
  final VoidCallback onReupload;
  const _PendingPreview({required this.fileName, required this.onReupload});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.insert_drive_file_rounded,
            color: AppTheme.warningLight,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Awaiting admin verification…',
                  style: TextStyle(color: AppTheme.warningLight, fontSize: 10),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onReupload,
            child: Text(
              'Replace',
              style: TextStyle(
                color: AppTheme.driverCyan,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Rejected row ─────────────────────────────────────────────────────────────
class _RejectedRow extends StatelessWidget {
  final String? reason;
  final VoidCallback onReupload;
  const _RejectedRow({required this.reason, required this.onReupload});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.cancel_rounded, color: AppTheme.errorLight, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              reason == null || reason!.isEmpty
                  ? 'Document rejected — please re-upload.'
                  : 'Rejected: $reason',
              style: TextStyle(color: AppTheme.errorLight, fontSize: 11),
            ),
          ),
          GestureDetector(
            onTap: onReupload,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Re-upload',
                style: TextStyle(
                  color: AppTheme.errorLight,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Status badge ─────────────────────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final DocumentStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color border;
    final Color textColor;
    final String label;
    final IconData icon;

    switch (status) {
      case DocumentStatus.verified:
        bg = AppTheme.success.withValues(alpha: 0.15);
        border = AppTheme.success.withValues(alpha: 0.3);
        textColor = AppTheme.successLight;
        label = 'Verified';
        icon = Icons.verified_rounded;
        break;
      case DocumentStatus.pending:
        bg = AppTheme.warning.withValues(alpha: 0.15);
        border = AppTheme.warning.withValues(alpha: 0.3);
        textColor = AppTheme.warningLight;
        label = 'Pending';
        icon = Icons.hourglass_top_rounded;
        break;
      case DocumentStatus.rejected:
        bg = AppTheme.error.withValues(alpha: 0.15);
        border = AppTheme.error.withValues(alpha: 0.3);
        textColor = AppTheme.errorLight;
        label = 'Rejected';
        icon = Icons.cancel_rounded;
        break;
      case DocumentStatus.notUploaded:
        bg = context.cardBgElevated;
        border = context.surfaceBorder;
        textColor = context.textTertiary;
        label = 'Required';
        icon = Icons.upload_file_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Image source picker sheet ────────────────────────────────────────────────
class _PickerSheet extends StatelessWidget {
  final String docTitle;
  const _PickerSheet({required this.docTitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.surfaceBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: context.surfaceBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(
            'Upload $docTitle',
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Choose how to add your document',
            style: TextStyle(color: context.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _PickerOption(
                  icon: Icons.camera_alt_rounded,
                  label: 'Camera',
                  color: AppTheme.driverCyan,
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PickerOption(
                  icon: Icons.photo_library_rounded,
                  label: 'Gallery',
                  color: AppTheme.purple,
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: context.cardBgElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.surfaceBorder),
              ),
              child: Center(
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: context.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PickerOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _PickerOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Summary pill ─────────────────────────────────────────────────────────────
class _SummaryPill extends StatelessWidget {
  final String icon, value, label;
  final Color color;
  const _SummaryPill({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(icon, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: context.textTertiary, fontSize: 11),
        ),
      ],
    );
  }
}
