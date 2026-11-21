import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:transit_core/transit_core.dart';

import '../theme/app_theme.dart';

/// How the AI slip / document check is shown: a small badge on list rows, a
/// details card in review sheets, and the sheet a parent or driver sees
/// right after picking an image. Shared by every role so the wording of a
/// warning is the same wherever it appears.

String _when(DateTime d) => DateFormat('d MMM y, h:mm a').format(d);
String _day(DateTime d) => DateFormat('d MMM y').format(d);

String _engineLabel(String engine) => switch (engine) {
  'gemini' => 'read by Gemini',
  'ocr+gemini' => 'read on this phone + Gemini',
  _ => 'read on this phone',
};

/// "✅ AI: matches" / "⚠️ AI: 2 issues".
class AiCheckBadge extends StatelessWidget {
  final bool matches;
  final int issueCount;
  final bool dense;

  const AiCheckBadge({
    super.key,
    required this.matches,
    required this.issueCount,
    this.dense = false,
  });

  factory AiCheckBadge.slip(SlipCheck c, {bool dense = false}) => AiCheckBadge(
    matches: c.matches,
    issueCount: c.issues.length,
    dense: dense,
  );

  factory AiCheckBadge.doc(DocCheck c, {bool dense = false}) => AiCheckBadge(
    matches: c.matches,
    issueCount: c.issues.length,
    dense: dense,
  );

  @override
  Widget build(BuildContext context) {
    final color = matches ? AppTheme.success : AppTheme.warning;
    final label = matches
        ? '✅ AI: matches'
        : '⚠️ AI: $issueCount issue${issueCount == 1 ? '' : 's'}';
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 6 : 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: matches ? AppTheme.success : AppTheme.warning,
          fontSize: dense ? 10 : 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  final String label;
  final String value;
  const _Line(this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 96,
          child: Text(
            label,
            style: TextStyle(color: context.textTertiary, fontSize: 12),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

class _IssueList extends StatelessWidget {
  final List<String> messages;
  final Color color;
  final String bullet;
  const _IssueList(this.messages, {required this.color, this.bullet = '⚠️'});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final m in messages)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(bullet, style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  m,
                  style: TextStyle(color: color, fontSize: 12.5, height: 1.3),
                ),
              ),
            ],
          ),
        ),
    ],
  );
}

/// Everything the slip check read, and what it found wrong.
class SlipCheckDetails extends StatelessWidget {
  final SlipCheck check;
  const SlipCheckDetails({super.key, required this.check});

  @override
  Widget build(BuildContext context) {
    final c = check;
    final color = c.matches ? AppTheme.success : AppTheme.warning;
    final receiver = [
      if ((c.receiverName ?? '').isNotEmpty) c.receiverName!,
      if ((c.receiverAccountLast4 ?? '').isNotEmpty)
        '••${c.receiverAccountLast4}',
    ].join(' · ');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  c.matches
                      ? 'AI check: matches the bill'
                      : 'AI check: please look closely',
                  style: TextStyle(
                    color: context.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
              AiCheckBadge.slip(c, dense: true),
            ],
          ),
          const SizedBox(height: 4),
          if (c.amountLabel != null) _Line('Amount', c.amountLabel!),
          if ((c.transactionId ?? '').isNotEmpty)
            _Line('Transaction ID', c.transactionId!),
          if (c.paidAt != null) _Line('Date', _when(c.paidAt!)),
          if (receiver.isNotEmpty) _Line('Sent to', receiver),
          if ((c.senderName ?? '').isNotEmpty) _Line('Sent by', c.senderName!),
          if (c.provider != 'unknown') _Line('App', c.providerLabel),
          if (c.issues.isNotEmpty)
            _IssueList(c.messages(), color: context.textPrimary),
          const SizedBox(height: 6),
          Text(
            'Automatic check (${_engineLabel(c.engine)}) — it can be wrong. '
            'Always confirm the money in your account.',
            style: TextStyle(color: context.textTertiary, fontSize: 10.5),
          ),
        ],
      ),
    );
  }
}

/// Everything the document check read, and what it found wrong.
class DocCheckDetails extends StatelessWidget {
  final DocCheck check;
  const DocCheckDetails({super.key, required this.check});

  @override
  Widget build(BuildContext context) {
    final c = check;
    final color = c.matches ? AppTheme.success : AppTheme.warning;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  c.matches ? 'AI check: looks right' : 'AI check: please look',
                  style: TextStyle(
                    color: context.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
              AiCheckBadge.doc(c, dense: true),
            ],
          ),
          const SizedBox(height: 4),
          for (final f in c.displayFields) _Line(f.key, f.value),
          if (c.nameMatchPercent != null)
            _Line('Name match', '${c.nameMatchPercent}%'),
          if (c.expiryDate != null && !c.fields.containsKey('expiryDate'))
            _Line('Valid until', _day(c.expiryDate!)),
          if (c.issues.isNotEmpty)
            _IssueList(c.messages(), color: context.textPrimary),
          if (c.notes.isNotEmpty)
            _IssueList(
              c.noteMessages(),
              color: context.textSecondary,
              bullet: 'ℹ️',
            ),
          const SizedBox(height: 6),
          Text(
            'Automatic check (${_engineLabel(c.engine)}) — an admin still '
            'verifies every document.',
            style: TextStyle(color: context.textTertiary, fontSize: 10.5),
          ),
        ],
      ),
    );
  }
}

/// A sheet with nothing but [details] in it — tapping a badge in a list.
Future<void> _showDetailsSheet(BuildContext context, Widget details) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
        decoration: BoxDecoration(
          color: ctx.cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(child: details),
        ),
      ),
    );

Future<void> showSlipCheckDetails(BuildContext context, SlipCheck check) =>
    _showDetailsSheet(context, SlipCheckDetails(check: check));

Future<void> showDocCheckDetails(BuildContext context, DocCheck check) =>
    _showDetailsSheet(context, DocCheckDetails(check: check));

/// What the person chose after seeing a check.
enum AiCheckChoice { proceed, chooseAnother }

/// The sheet shown right after an image is checked — before anything is
/// uploaded. It never blocks: "Send anyway" is always there.
Future<AiCheckChoice?> showAiCheckSheet(
  BuildContext context, {
  required Widget details,
  required bool matches,
  required Color accent,
  required String proceedLabel,
  required String proceedAnywayLabel,
  required String chooseAnotherLabel,
}) => showModalBottomSheet<AiCheckChoice>(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  builder: (ctx) => Container(
    padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
    decoration: BoxDecoration(
      color: ctx.cardBg,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
    ),
    child: SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            details,
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx, AiCheckChoice.proceed),
                style: ElevatedButton.styleFrom(
                  backgroundColor: matches ? accent : AppTheme.warning,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(matches ? proceedLabel : proceedAnywayLabel),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () =>
                    Navigator.pop(ctx, AiCheckChoice.chooseAnother),
                style: OutlinedButton.styleFrom(
                  foregroundColor: accent,
                  side: BorderSide(color: accent),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(chooseAnotherLabel),
              ),
            ),
          ],
        ),
      ),
    ),
  ),
);

/// A slip check's warnings, asked again before the driver marks a payment
/// received. True to go ahead.
Future<bool> confirmDespiteSlipWarnings(
  BuildContext context,
  SlipCheck check,
) async {
  if (check.matches) return true;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('AI check found issues'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _IssueList(check.messages(), color: ctx.textPrimary),
            const SizedBox(height: 10),
            Text(
              'Only mark it received if the money is really in your account.',
              style: TextStyle(color: ctx.textSecondary, fontSize: 12.5),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Go back'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Money received'),
        ),
      ],
    ),
  );
  return ok ?? false;
}
