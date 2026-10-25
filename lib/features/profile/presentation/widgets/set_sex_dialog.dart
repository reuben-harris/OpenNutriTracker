import 'package:flutter/material.dart';
import 'package:opennutritracker/core/domain/entity/user_sex_entity.dart';
import 'package:opennutritracker/core/presentation/sources_screen.dart';
import 'package:opennutritracker/generated/l10n.dart';

class SetSexDialog extends StatelessWidget {
  const SetSexDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      title: Row(
        children: [
          Expanded(
            child: Text(
              S.of(context).selectSexDialogLabel,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: S.of(context).sourcesIconTooltip,
            icon: const Icon(Icons.info_outline),
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SourcesScreen())),
          ),
        ],
      ),
      children: [
        SimpleDialogOption(
          child: Text(S.of(context).sexMaleLabel),
          onPressed: () {
            Navigator.pop(context, UserSexEntity.male);
          },
        ),
        SimpleDialogOption(
          child: Text(S.of(context).sexFemaleLabel),
          onPressed: () {
            Navigator.pop(context, UserSexEntity.female);
          },
        ),
      ],
    );
  }
}
