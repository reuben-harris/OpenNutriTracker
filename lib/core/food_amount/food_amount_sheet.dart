import 'package:opennutritracker/core/food_amount/food_amount_expression.dart';
import 'package:opennutritracker/core/food_amount/food_amount_memory.dart';
import 'package:opennutritracker/core/utils/hive_db_provider.dart';
import 'dart:async';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/core/food_amount/food_amount.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/meal_detail/presentation/bloc/meal_detail_bloc.dart';
import 'package:opennutritracker/generated/l10n.dart';

Future<bool> showFoodAmountSheet(
  BuildContext context, {
  required MealEntity meal,
  required Future<bool> Function(MealEntity, FoodAmountSelection) onConfirm,
  FoodAmountSelection? initial,
  bool editing = false,
  bool hydrate = true,
}) async {
  final config = await locator<GetConfigUsecase>().getConfig();
  FoodAmountMemory? memory;
  HiveDBProvider? profiles;
  String? profile;
  if (locator.isRegistered<HiveDBProvider>()) {
    profiles = locator<HiveDBProvider>();
    profile = profiles.activeProfileId;
    try {
      memory = FoodAmountMemory(profiles.foodAmountMemoryBox);
    } catch (_) {
      /* Convenience defaults cannot block amount entry. */
    }
  }
  if (!context.mounted) return false;
  return await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        showDragHandle: false,
        enableDrag: false,
        builder: (_) => FoodAmountSheet(
          meal: meal,
          onConfirm: (food, selection) async {
            if (profiles != null && profiles.activeProfileId != profile) {
              throw StateError('Profile changed');
            }
            return onConfirm(food, selection);
          },
          remembered: memory?.read(meal),
          onRemember: memory?.remember,
          initial: initial,
          editing: editing,
          hydrate: hydrate,
          arithmetic: config.amountArithmeticEnabled,
          imperial: config.usesImperialFoodUnits,
          rawUnits: config.defaultToRawFoodUnits,
        ),
      ) ??
      false;
}

class FoodAmountSheet extends StatefulWidget {
  const FoodAmountSheet({
    super.key,
    required this.meal,
    required this.onConfirm,
    this.initial,
    this.remembered,
    this.onRemember,
    this.editing = false,
    this.hydrate = true,
    this.arithmetic = false,
    this.imperial = false,
    this.rawUnits = false,
  });
  final MealEntity meal;
  final Future<bool> Function(MealEntity, FoodAmountSelection) onConfirm;
  final FoodAmountSelection? initial;
  final FoodAmountPreference? remembered;
  final Future<void> Function(MealEntity, FoodAmountSelection)? onRemember;
  final bool editing, hydrate, imperial, rawUnits, arithmetic;
  @override
  State<FoodAmountSheet> createState() => _FoodAmountSheetState();
}

class _FoodAmountSheetState extends State<FoodAmountSheet> {
  late MealEntity _meal;
  late FoodAmountOption _option;
  late TextEditingController _amount;
  final _focus = FocusNode();
  MealDetailBloc? _details;
  StreamSubscription<MealDetailState>? _subscription;
  bool _changed = false, _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _meal = widget.meal;
    final initial =
        widget.initial ??
        supportedRememberedAmount(_meal, widget.remembered) ??
        _default();
    _option = initial.option;
    _amount = TextEditingController(text: formatFoodAmount(initial.amount));
    _selectAll();
    if (widget.hydrate && locator.isRegistered<MealDetailBloc>()) {
      _details = locator<MealDetailBloc>();
      _subscription = _details!.stream.listen((state) {
        final full = state.hydratedMeal;
        if (!mounted || full == null || identical(full, _meal)) return;
        setState(() {
          _meal = full;
          // Hydration can reveal a default serving, but cannot replace input.
          if (!_changed && !_saving && widget.initial == null) {
            final initial =
                supportedRememberedAmount(_meal, widget.remembered) ??
                _default();
            _option = initial.option;
            _amount.text = formatFoodAmount(initial.amount);
            _selectAll();
          }
        });
      });
      _details!.add(HydrateMealEvent(_meal));
    }
  }

  FoodAmountSelection _default() => defaultFoodAmount(
    _meal,
    imperial: widget.imperial,
    rawUnits: widget.rawUnits,
  );
  void _selectAll() => _amount.selection = TextSelection(
    baseOffset: 0,
    extentOffset: _amount.text.length,
  );
  @override
  void dispose() {
    _subscription?.cancel();
    _details?.close();
    _amount.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_saving) return;
    double? value;
    try {
      value = evaluateFoodAmount(_amount.text, arithmetic: widget.arithmetic);
    } on FormatException {
      /* Show the same inline validation as a missing amount. */
    }
    if (value == null ||
        !value.isFinite ||
        value <= 0 ||
        !_option.isValid ||
        !_option.toBase(value).isFinite ||
        _option.toBase(value) <= 0) {
      setState(() => _error = S.of(context).foodAmountInvalidLabel);
      return;
    }
    final selected = FoodAmountSelection(value, _option);
    final food = _meal;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await widget.onConfirm(food, selected);
      if (!mounted) return;
      if (saved) {
        try {
          await widget.onRemember?.call(food, selected);
        } catch (_) {
          /* Saving the food already succeeded. */
        }
        if (mounted) Navigator.of(context).pop(true);
        return;
      }
    } catch (_) {
      if (mounted) setState(() => _error = S.of(context).quickAddReuseFailed);
    }
    if (mounted) setState(() => _saving = false);
  }

  double? _preview() {
    if (!RegExp(r'[+−\-×*/÷]').hasMatch(_amount.text)) return null;
    try {
      return evaluateFoodAmount(_amount.text, arithmetic: true);
    } on FormatException {
      return null;
    }
  }

  void _insertOperator(String operator) {
    final text = _amount.text;
    final selection = _amount.selection;
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;
    setState(() {
      _changed = true;
      _error = null;
      _amount.value = TextEditingValue(
        text: text.replaceRange(start, end, operator),
        selection: TextSelection.collapsed(offset: start + operator.length),
      );
    });
    _focus.requestFocus();
  }

  void _normalizeExpression() {
    try {
      final value = evaluateFoodAmount(_amount.text, arithmetic: true);
      if (value <= 0) throw const FormatException('Non-positive amount');
      setState(() {
        _changed = true;
        _amount.text = formatFoodAmount(value);
        _selectAll();
        _error = null;
      });
    } on FormatException {
      setState(() => _error = S.of(context).foodAmountInvalidLabel);
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = foodAmountOptions(_meal);
    final at = options.indexWhere((o) => o.identity == _option.identity);
    if (at < 0) {
      options.insert(0, _option);
    } else {
      options[at] = _option;
    }
    return PopScope(
      canPop: !_saving,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            8,
            24,
            16 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AutoSizeText(
                  _meal.name ?? '?',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Semantics(
                        identifier: 'food-amount-input',
                        child: TextField(
                          controller: _amount,
                          focusNode: _focus,
                          autofocus: true,
                          enabled: !_saving,
                          keyboardType: TextInputType.numberWithOptions(
                            decimal: true,
                            signed: widget.arithmetic,
                          ),
                          textInputAction: TextInputAction.done,
                          inputFormatters: [
                            TextInputFormatter.withFunction(
                              (old, next) =>
                                  (widget.arithmetic
                                          ? RegExp(r'^[0-9.,\s+−\-×*/÷]*$')
                                          : RegExp(r'^\d*(?:[.,]\d*)?$'))
                                      .hasMatch(next.text)
                                  ? next
                                  : old,
                            ),
                          ],
                          onChanged: (_) => setState(() {
                            _changed = true;
                            _error = null;
                          }),
                          onSubmitted: (_) => widget.arithmetic
                              ? _normalizeExpression()
                              : _confirm(),
                          decoration: InputDecoration(
                            labelText: S.of(context).quantityLabel,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: Semantics(
                        identifier: 'food-amount-unit',
                        child: DropdownButtonFormField<String>(
                          key: ValueKey(_option.identity),
                          initialValue: _option.identity,
                          isExpanded: true,
                          itemHeight: null,
                          decoration: InputDecoration(
                            labelText: S.of(context).unitLabel,
                            border: const OutlineInputBorder(),
                          ),
                          items: options
                              .map(
                                (option) => DropdownMenuItem(
                                  value: option.identity,
                                  child: Text(
                                    option.unit == 'serving' &&
                                            option.label == null
                                        ? S.of(context).servingLabel
                                        : option.displayLabel,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: _saving
                              ? null
                              : (id) => setState(() {
                                  _changed = true;
                                  _option = options.firstWhere(
                                    (o) => o.identity == id,
                                  );
                                }),
                        ),
                      ),
                    ),
                  ],
                ),
                if (widget.arithmetic)
                  TextFieldTapRegion(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Wrap(
                        spacing: 8,
                        children: [
                          for (final (operator, name) in const [
                            ('+', 'add'),
                            ('−', 'subtract'),
                            ('×', 'multiply'),
                            ('÷', 'divide'),
                          ])
                            Semantics(
                              identifier: 'food-amount-operator-$name',
                              child: Focus(
                                canRequestFocus: false,
                                descendantsAreFocusable: false,
                                child: OutlinedButton(
                                  onPressed: _saving
                                      ? null
                                      : () => _insertOperator(operator),
                                  child: Text(operator),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                if (widget.arithmetic && _preview() != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Semantics(
                      identifier: 'food-amount-result',
                      child: Text('= ${formatFoodAmount(_preview()!)}'),
                    ),
                  ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                Semantics(
                  identifier: 'food-amount-cancel',
                  child: TextButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(false),
                    child: Text(S.of(context).dialogCancelLabel),
                  ),
                ),
                Semantics(
                  identifier: 'food-amount-confirm',
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _saving ? null : _confirm,
                      child: _saving
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              widget.editing
                                  ? S.of(context).recipeSaveLabel
                                  : S.of(context).addLabel,
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
