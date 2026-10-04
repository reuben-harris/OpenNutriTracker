import 'package:flutter/material.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/features/diary/presentation/widgets/diary_transfer_style.dart';
import 'package:opennutritracker/generated/l10n.dart';

class DiaryDragTargets extends StatelessWidget {
  final ValueChanged<IntakeEntity> onDelete;
  final ValueChanged<IntakeEntity> onCopy;
  final ValueChanged<IntakeEntity>? onExplode;
  const DiaryDragTargets({
    super.key,
    required this.onDelete,
    required this.onCopy,
    this.onExplode,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      if (onExplode != null) ...[
        Expanded(
          child: _target(
            context,
            'diary-explode-target',
            S.of(context).explodeRecipeLabel,
            Icons.call_split_rounded,
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.onPrimary,
            onExplode!,
          ),
        ),
        const SizedBox(width: 12),
      ],
      Expanded(
        child: _target(
          context,
          'diary-delete-target',
          S.of(context).dialogDeleteLabel,
          Icons.delete_rounded,
          Theme.of(context).colorScheme.error,
          Theme.of(context).colorScheme.onError,
          onDelete,
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: _target(
          context,
          'diary-copy-target',
          S.of(context).copyActionLabel,
          Icons.copy_rounded,
          diaryCopyButtonColor,
          Colors.white,
          onCopy,
        ),
      ),
    ],
  );

  Widget _target(
    BuildContext context,
    String id,
    String label,
    IconData icon,
    Color color,
    Color foreground,
    ValueChanged<IntakeEntity> accept,
  ) => DragTarget<IntakeEntity>(
    onAcceptWithDetails: (details) => accept(details.data),
    builder: (_, candidates, rejected) => Semantics(
      identifier: id,
      label: label,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: diaryTransferDecoration(
          color,
          foreground: foreground,
          hovering: candidates.isNotEmpty,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: foreground, size: 32),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: foreground),
            ),
          ],
        ),
      ),
    ),
  );
}
