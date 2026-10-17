import 'package:flutter/material.dart';
import 'package:opennutritracker/generated/l10n.dart';

Future<bool?> confirmRecipeExplosion(BuildContext context) => showDialog<bool>(
  context: context,
  builder: (context) {
    final s = S.of(context);
    return AlertDialog(
      title: Text(s.explodeRecipeConfirmTitle),
      content: Text(s.explodeRecipeOneWayHint),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(s.dialogCancelLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(s.explodeRecipeLabel),
        ),
      ],
    );
  },
);
