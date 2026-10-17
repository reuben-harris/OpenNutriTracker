import 'package:flutter/material.dart';
import 'package:opennutritracker/core/food_amount/food_amount.dart';
import 'package:opennutritracker/core/styles/dimens.dart';
import 'package:opennutritracker/features/recipes/presentation/bloc/recipe_builder_bloc.dart';
import 'package:opennutritracker/generated/l10n.dart';

class RecipeWeightEditor extends StatefulWidget {
  const RecipeWeightEditor({
    super.key,
    required this.mode,
    required this.fieldBorder,
    this.showError = false,
    required this.totalWeightG,
    required this.cookedWeightG,
    required this.onModeChanged,
    required this.onCookedWeightChanged,
  });

  final RecipeWeightMode mode;
  final InputBorder fieldBorder;
  final bool showError;
  final double? totalWeightG;
  final double? cookedWeightG;
  final ValueChanged<RecipeWeightMode> onModeChanged;
  final ValueChanged<double?> onCookedWeightChanged;

  @override
  State<RecipeWeightEditor> createState() => _RecipeWeightEditorState();
}

class _RecipeWeightEditorState extends State<RecipeWeightEditor> {
  late final TextEditingController _controller;

  String get _initialText => widget.cookedWeightG == null
      ? ''
      : formatFoodAmount(widget.cookedWeightG!);

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _initialText);
  }

  @override
  void didUpdateWidget(RecipeWeightEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.mode != oldWidget.mode) {
      _controller.text = _initialText;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          identifier: 'recipe-weight-mode',
          child: LayoutBuilder(
            builder: (context, constraints) =>
                SegmentedButton<RecipeWeightMode>(
                  direction:
                      constraints.maxWidth <
                          MediaQuery.textScalerOf(context).scale(360)
                      ? Axis.vertical
                      : Axis.horizontal,
                  segments: [
                    ButtonSegment(
                      value: RecipeWeightMode.automatic,
                      label: Text(s.recipeWeightAutomaticLabel),
                    ),
                    ButtonSegment(
                      value: RecipeWeightMode.custom,
                      label: Text(s.recipeWeightCustomLabel),
                    ),
                  ],
                  selected: {widget.mode},
                  onSelectionChanged: (selection) =>
                      widget.onModeChanged(selection.single),
                ),
          ),
        ),
        const SizedBox(height: Dimens.spacing16),
        if (widget.mode == RecipeWeightMode.automatic)
          InputDecorator(
            decoration: InputDecoration(
              labelText: s.recipeTotalWeightLabel,
              helperText: s.recipeTotalWeightHelper,
              helperMaxLines: 3,
              border: widget.fieldBorder,
              enabledBorder: widget.fieldBorder,
              focusedBorder: widget.fieldBorder,
              errorBorder: widget.fieldBorder,
              focusedErrorBorder: widget.fieldBorder,
            ),
            child: Text(
              widget.totalWeightG == null
                  ? '—'
                  : formatFoodAmount(widget.totalWeightG!),
            ),
          )
        else
          Semantics(
            identifier: 'recipe-cooked-weight-input',
            child: TextField(
              controller: _controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: s.recipeCookedWeightLabel,
                errorText: widget.showError
                    ? s.recipeInvalidTotalWeightLabel
                    : null,
                border: widget.fieldBorder,
                enabledBorder: widget.fieldBorder,
                focusedBorder: widget.fieldBorder,
                errorBorder: widget.fieldBorder,
                focusedErrorBorder: widget.fieldBorder,
              ),
              onChanged: (value) {
                final parsed = RegExp(r'^\d+(?:[.,]\d*)?$').hasMatch(value)
                    ? double.tryParse(value.replaceAll(',', '.'))
                    : null;
                widget.onCookedWeightChanged(parsed);
              },
            ),
          ),
      ],
    );
  }
}
