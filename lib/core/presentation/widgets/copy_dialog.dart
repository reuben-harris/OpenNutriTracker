import 'package:flutter/material.dart';
import 'package:opennutritracker/features/add_meal/presentation/add_meal_type.dart';
import 'package:opennutritracker/generated/l10n.dart';

enum CopyDirection { from, to }

class CopyDialog extends StatefulWidget {
  final AddMealType initialValue;
  final CopyDirection direction;
  final Set<AddMealType>? availableSources;

  const CopyDialog({
    super.key,
    required this.initialValue,
    required this.direction,
    this.availableSources,
  });
  @override
  State<StatefulWidget> createState() {
    return CopyDialogState();
  }
}

class CopyDialogState extends State<CopyDialog> {
  late AddMealType _selectedValue;

  AddMealType get selectedMealType => _selectedValue;

  @override
  void initState() {
    super.initState();
    _selectedValue = widget.initialValue;
  }

  bool _isEmptySource(AddMealType type) =>
      widget.direction == CopyDirection.from &&
      widget.availableSources != null &&
      !widget.availableSources!.contains(type);

  void _showEmptySource(AddMealType type) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            S.of(context).diaryYesterdayEmptyMessage(type.getTypeName(context)),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    // Preserve localized word order while styling only the direction.
    final titleParts = s.copyDialogTitle('{direction}').split('{direction}');
    final direction = widget.direction == CopyDirection.from
        ? s.copyDialogFromDirection
        : s.copyDialogToDirection;
    return AlertDialog(
      title: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: titleParts.first),
            TextSpan(
              text: direction,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            TextSpan(text: titleParts.last),
          ],
        ),
      ),
      content: Semantics(
        identifier: widget.direction == CopyDirection.from
            ? 'diary-copy-source-meal'
            : 'diary-copy-destination-meal',
        child: DropdownButton<AddMealType>(
          value: _selectedValue,
          itemHeight: null,
          onChanged: (AddMealType? addMealType) {
            if (addMealType != null) {
              if (_isEmptySource(addMealType)) {
                _showEmptySource(addMealType);
                return;
              }
              setState(() {
                _selectedValue = addMealType;
              });
            }
          },
          items: AddMealType.values.map((AddMealType addMealType) {
            return DropdownMenuItem(
              value: addMealType,
              child: Text(
                addMealType.getTypeName(context),
                style: _isEmptySource(addMealType)
                    ? TextStyle(color: Theme.of(context).disabledColor)
                    : null,
                semanticsLabel: _isEmptySource(addMealType)
                    ? s.diaryYesterdayEmptyMessage(
                        addMealType.getTypeName(context),
                      )
                    : null,
              ),
            );
          }).toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            if (_isEmptySource(_selectedValue)) {
              _showEmptySource(_selectedValue);
              return;
            }
            Navigator.of(context).pop(_selectedValue);
          },
          child: Text(S.of(context).dialogOKLabel),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text(S.of(context).dialogCancelLabel),
        ),
      ],
    );
  }
}
