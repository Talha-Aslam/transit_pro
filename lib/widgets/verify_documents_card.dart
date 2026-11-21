import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:transit_core/transit_core.dart';

import '../app/driver_documents.dart';
import '../app/session_service.dart';
import '../data/user_repository.dart';
import '../theme/app_theme.dart';

/// "Verify Documents" on the driver's home screen.
///
/// Stays on the home screen until every required document has been
/// submitted (pending or verified), so verification is always one tap away.
/// A rejected document counts as not submitted and is called out, because
/// the driver has to replace it. Tapping opens Profile → Documents & License.
class VerifyDocumentsCard extends StatefulWidget {
  const VerifyDocumentsCard({super.key});

  @override
  State<VerifyDocumentsCard> createState() => _VerifyDocumentsCardState();
}

class _VerifyDocumentsCardState extends State<VerifyDocumentsCard> {
  StreamSubscription<List<DriverDocument>>? _sub;
  List<DriverDocument>? _docs;

  @override
  void initState() {
    super.initState();
    final uid = SessionService.instance.uid;
    if (uid == null) return;
    _sub = UserRepository.instance.watchDriverDocuments(uid).listen((docs) {
      unawaited(fixSignupCnicMislabels(docs));
      if (mounted) setState(() => _docs = docs);
    }, onError: (Object e) => debugPrint('verify documents card: $e'));
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final docs = _docs;
    // Nothing until the first snapshot, so a fully verified driver never
    // sees the card flash up on launch.
    if (docs == null) return const SizedBox.shrink();
    final needed = documentsStillNeeded(docs);
    if (needed.isEmpty) return const SizedBox.shrink();
    final rejected = documentsRejected(docs);
    final total = kRequiredDriverDocuments.length;
    final done = total - needed.length;
    final hasRejected = rejected.isNotEmpty;
    final accent = hasRejected ? AppTheme.error : AppTheme.warning;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => context.push('/driver/documents'),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: accent.withValues(alpha: 0.45)),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    hasRejected
                        ? Icons.error_outline_rounded
                        : Icons.verified_user_outlined,
                    color: accent,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Verify Documents',
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hasRejected
                            ? 'Re-upload: ${rejected.map(driverDocumentName).join(', ')}'
                            : 'Still needed: ${needed.map(driverDocumentName).join(', ')}',
                        style: TextStyle(
                          color: context.textSecondary,
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: total == 0 ? 0 : done / total,
                          minHeight: 6,
                          backgroundColor: accent.withValues(alpha: 0.15),
                          color: accent,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$done of $total submitted',
                        style: TextStyle(
                          color: context.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: accent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
