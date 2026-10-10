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

Future<bool> showFoodAmountSheet(BuildContext context, {required MealEntity meal,
  required Future<bool> Function(MealEntity, FoodAmountSelection) onConfirm,
  FoodAmountSelection? initial, bool editing = false, bool hydrate = true}) async {
  final config = await locator<GetConfigUsecase>().getConfig();
  if (!context.mounted) return false;
  return await showModalBottomSheet<bool>(context: context, isScrollControlled: true,
    showDragHandle: true, enableDrag: false, isDismissible: false, builder: (_) => FoodAmountSheet(meal: meal, onConfirm: onConfirm,
      initial: initial, editing: editing, hydrate: hydrate,
      imperial: config.usesImperialFoodUnits, rawUnits: config.defaultToRawFoodUnits)) ?? false;
}

class FoodAmountSheet extends StatefulWidget {
  const FoodAmountSheet({super.key, required this.meal, required this.onConfirm,
    this.initial, this.editing = false, this.hydrate = true,
    this.imperial = false, this.rawUnits = false});
  final MealEntity meal;
  final Future<bool> Function(MealEntity, FoodAmountSelection) onConfirm;
  final FoodAmountSelection? initial;
  final bool editing, hydrate, imperial, rawUnits;
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
    final initial = widget.initial ?? _default();
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
          if (!_changed && widget.initial == null) {
            final initial = _default();
            _option = initial.option;
            _amount.text = formatFoodAmount(initial.amount);
            _selectAll();
          }
        });
      });
      _details!.add(HydrateMealEvent(_meal));
    }
  }
  FoodAmountSelection _default() => defaultFoodAmount(_meal, imperial: widget.imperial, rawUnits: widget.rawUnits);
  void _selectAll() => _amount.selection = TextSelection(baseOffset: 0, extentOffset: _amount.text.length);
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
    final value = double.tryParse(_amount.text.trim().replaceAll(',', '.'));
    if (value == null || !value.isFinite || value <= 0 || !_option.isValid || !(_option.toBase(value).isFinite)) {
      setState(() => _error = S.of(context).foodAmountInvalidLabel);
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      final saved = await widget.onConfirm(_meal, FoodAmountSelection(value, _option));
      if (!mounted) return;
      if (saved) { Navigator.of(context).pop(true); return; }
    } catch (_) {
      if (mounted) setState(() => _error = S.of(context).quickAddReuseFailed);
    }
    if (mounted) setState(() => _saving = false);
  }
  @override
  Widget build(BuildContext context) {
    final options = foodAmountOptions(_meal);
    final at = options.indexWhere((o) => o.identity == _option.identity);
    if (at < 0) { options.insert(0, _option); } else { options[at] = _option; }
    return PopScope(canPop: !_saving, child: SafeArea(top: false, child: Padding(
      padding: EdgeInsets.fromLTRB(24, 8, 24, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          AutoSizeText(_meal.name ?? '?', maxLines: 2, overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(flex: 3, child: Semantics(identifier: 'food-amount-input', child: TextField(
              controller: _amount, focusNode: _focus, autofocus: true, enabled: !_saving,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.done,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
              onChanged: (_) { _changed = true; if (_error != null) setState(() => _error = null); },
              onSubmitted: (_) => _confirm(),
              decoration: InputDecoration(labelText: S.of(context).quantityLabel,
                border: const OutlineInputBorder()),
            ))),
            const SizedBox(width: 12),
            Expanded(flex: 2, child: Semantics(identifier: 'food-amount-unit', child: DropdownButtonFormField<String>(
              key: ValueKey(_option.identity), initialValue: _option.identity, isExpanded: true, itemHeight: null,
              decoration: InputDecoration(labelText: S.of(context).unitLabel, border: const OutlineInputBorder()),
              items: options.map((option) => DropdownMenuItem(value: option.identity,
                child: Text(option.unit == 'serving' && option.label == null ? S.of(context).servingLabel : option.displayLabel,
                  maxLines: 2, overflow: TextOverflow.ellipsis))).toList(),
              onChanged: _saving ? null : (id) => setState(() { _changed = true; _option = options.firstWhere((o) => o.identity == id); }),
            ))),
          ]),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 8),
            child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
          const SizedBox(height: 16),
          Semantics(identifier: 'food-amount-cancel', child: TextButton(onPressed: _saving ? null : () => Navigator.of(context).pop(false), child: Text(S.of(context).dialogCancelLabel))),
          Semantics(identifier: 'food-amount-confirm', child: SizedBox(width: double.infinity,
            child: FilledButton(onPressed: _saving ? null : _confirm,
              child: _saving ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(widget.editing ? S.of(context).recipeSaveLabel : S.of(context).addLabel)))),
        ])),
    )));
  }
}
