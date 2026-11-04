import 'package:flutter/material.dart';
import 'package:transit_core/transit_core.dart';

import '../app/session_service.dart';
import '../theme/app_theme.dart';
import 'avatar_image.dart';

/// Which child a parent's screen is about.
///
/// A family with two children has two of everything — two drivers (or the
/// same driver on two different rounds), two schedules, two ratings, two
/// conversations. Screens that forgot to ask which child showed the first
/// one's details under the second one's name, which is worse than showing
/// nothing because a parent can act on it.
///
/// Hides itself for a family with one child: a picker with a single option
/// is a control that cannot do anything.
class ChildSelector extends StatelessWidget {
  /// Called after the selection changes, for a screen that has to refetch
  /// something — the selected index itself is shared state on
  /// [SessionService], so most screens need no callback at all.
  final VoidCallback? onChanged;

  final Color accent;

  const ChildSelector({
    super.key,
    this.onChanged,
    this.accent = AppTheme.parentPurple,
  });

  @override
  Widget build(BuildContext context) {
    final session = SessionService.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([
        session.children,
        session.selectedChildIndex,
      ]),
      builder: (context, _) {
        final children = session.children.value;
        if (children.length < 2) return const SizedBox.shrink();
        final selected = session.selectedChildIndex.value;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: SizedBox(
            height: 46,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: children.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) => _ChildChip(
                child: children[i],
                active: i == selected,
                accent: accent,
                onTap: () {
                  if (session.selectedChildIndex.value == i) return;
                  session.selectedChildIndex.value = i;
                  onChanged?.call();
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ChildChip extends StatelessWidget {
  final Student child;
  final bool active;
  final Color accent;
  final VoidCallback onTap;

  const _ChildChip({
    required this.child,
    required this.active,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
        decoration: BoxDecoration(
          color: active
              ? accent.withValues(alpha: 0.2)
              : context.cardBgElevated,
          borderRadius: BorderRadius.circular(23),
          border: Border.all(
            color: active ? accent : context.surfaceBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AvatarImage(
              localFile: null,
              photoUrl: child.photoUrl,
              size: 34,
              borderRadius: BorderRadius.circular(17),
              fallback: riderGlyph(child.instituteType, size: 16),
            ),
            const SizedBox(width: 9),
            Text(
              child.name.trim().isEmpty ? 'Child' : child.name.trim(),
              style: TextStyle(
                color: active ? context.textPrimary : context.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
