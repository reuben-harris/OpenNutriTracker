import 'package:opennutritracker/core/domain/entity/nutrient_amount.dart';
import 'package:opennutritracker/core/utils/food_amount_unit.dart';
import 'package:opennutritracker/core/food_amount/food_amount.dart';
import 'package:opennutritracker/core/data/data_source/custom_meal_data_source.dart';
import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';
import 'package:opennutritracker/core/domain/usecase/update_intake_usecase.dart';
import 'package:opennutritracker/core/utils/hive_db_provider.dart';
import 'package:opennutritracker/core/utils/food_name_validator.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:opennutritracker/core/utils/custom_text_input_formatter.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/domain/usecase/add_intake_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/add_tracked_day_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_kcal_goal_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_macro_goal_usecase.dart';
import 'package:opennutritracker/core/utils/calc/unit_calc.dart';
import 'package:opennutritracker/core/utils/energy_unit_provider.dart';
import 'package:opennutritracker/core/utils/id_generator.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/calendar_day_bloc.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/diary_bloc.dart';
import 'package:opennutritracker/features/home/presentation/bloc/home_bloc.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'package:provider/provider.dart';

class QuickAddBottomSheet extends StatefulWidget {
  final IntakeTypeEntity intakeType;
  final DateTime day;
  final MealEntity? initialMeal;
  final IntakeEntity? editingIntake;
  final Future<bool> Function(MealEntity, FoodAmountSelection)? onConfirm;

  const QuickAddBottomSheet({
    super.key,
    required this.intakeType,
    required this.day,
    this.initialMeal,
    this.editingIntake,
    this.onConfirm,
  });

  @override
  State<QuickAddBottomSheet> createState() => _QuickAddBottomSheetState();
}

class _QuickAddBottomSheetState extends State<QuickAddBottomSheet> {
  final _log = Logger('QuickAddBottomSheet');

  final _titleController = TextEditingController();
  final _energyController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fatController = TextEditingController();
  final _proteinController = TextEditingController();
  final _weightController = TextEditingController();
  FoodAmountUnit _weightUnit = FoodAmountUnit.g;
  String _initialWeightText = '';
  FoodAmountUnit _initialWeightUnit = FoodAmountUnit.g;

  bool _saving = false;
  final _initialText = <TextEditingController, String>{};
  bool _prefilled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_prefilled) return;
    _prefilled = true;
    final meal = widget.editingIntake?.meal ?? widget.initialMeal;
    if (meal == null) return;
    final amount =
        widget.editingIntake?.baseAmount ??
        (meal.hasQuickAddWeight ? double.parse(meal.mealQuantity!) : 100);
    final factor = amount / 100;
    if (meal.hasQuickAddWeight) {
      final entered = widget.editingIntake?.quantity;
      final enteredUnit = FoodAmountUnit.values
          .where((unit) => unit.label == entered?.option.unit)
          .firstOrNull;
      _weightUnit =
          enteredUnit ??
          FoodAmountUnit.fromLabel(meal.servingUnit ?? meal.mealUnit);
      _weightController.text = enteredUnit != null
          ? entered!.amount.toString()
          : _weightUnit.fromBase(amount).toString();
    }
    _initialWeightText = _weightController.text;
    _initialWeightUnit = _weightUnit;
    final usesKj = context.read<EnergyUnitProvider>().usesKilojoules;
    _titleController.text = meal.name ?? '';
    final n = meal.nutriments;
    final energy = n.energyKcal100 == null
        ? null
        : n.energyKcal100!.calculationValue * factor;
    _energyController.text = energy == null
        ? ''
        : (usesKj ? UnitCalc.kcalToKj(energy) : energy).toString();
    for (final entry in {
      _carbsController: n.carbohydrates100,
      _fatController: n.fat100,
      _proteinController: n.proteins100,
    }.entries) {
      entry.key.text = entry.value == null
          ? ''
          : (entry.value!.calculationValue * factor).toString();
    }
    for (final controller in [
      _energyController,
      _carbsController,
      _fatController,
      _proteinController,
    ]) {
      _initialText[controller] = controller.text;
    }
  }

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_onRequiredFieldChanged);
    for (final c in [
      _energyController,
      _carbsController,
      _fatController,
      _proteinController,
      _weightController,
    ]) {
      c.addListener(_onRequiredFieldChanged);
    }
  }

  @override
  void dispose() {
    _titleController.removeListener(_onRequiredFieldChanged);
    for (final c in [
      _energyController,
      _carbsController,
      _fatController,
      _proteinController,
      _weightController,
    ]) {
      c.removeListener(_onRequiredFieldChanged);
    }
    _titleController.dispose();
    _energyController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    _proteinController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _onRequiredFieldChanged() => setState(() {});

  double? _parsed(TextEditingController c) {
    final raw = c.text.trim().replaceAll(',', '.');
    if (raw.isEmpty) return null;
    final value = double.tryParse(raw);
    if (value == null || !value.isFinite || value < 0) return null;
    return value;
  }

  bool get _canSubmit {
    final weight = _parsed(_weightController);
    return (widget.onConfirm == null || weight != null && weight > 0) &&
        (_weightController.text.trim().isEmpty ||
            (weight != null &&
                weight > 0 &&
                _weightUnit.toBase(weight).isFinite)) &&
        !_saving &&
        FoodNameValidator.isValid(_titleController.text) &&
        [
          _energyController,
          _carbsController,
          _fatController,
          _proteinController,
        ].every((c) => c.text.trim().isEmpty || _parsed(c) != null);
  }

  Future<void> _onSubmit() async {
    if (!_canSubmit) return;
    setState(() => _saving = true);

    final usesKj = context.read<EnergyUnitProvider>().usesKilojoules;
    final profileBox = widget.onConfirm == null
        ? locator<HiveDBProvider>().intakeBox
        : null;
    final enteredEnergy = _parsed(_energyController);
    final kcal = enteredEnergy == null
        ? null
        : (usesKj ? UnitCalc.kjToKcal(enteredEnergy) : enteredEnergy);
    final carbs = _parsed(_carbsController);
    final fat = _parsed(_fatController);
    final protein = _parsed(_proteinController);
    final title = _titleController.text.trim();

    try {
      final intake = _buildIntake(
        kcal: kcal,
        carbs: carbs,
        fat: fat,
        protein: protein,
        title: title,
      );
      if (widget.onConfirm != null) {
        final saved = await widget.onConfirm!(intake.meal, intake.quantity!);
        if (!mounted) return;
        if (saved) {
          Navigator.of(context).pop();
        } else {
          setState(() => _saving = false);
        }
        return;
      }
      if (!identical(profileBox, locator<HiveDBProvider>().intakeBox)) return;
      final editing = widget.editingIntake;
      if (editing != null) {
        final updated = await locator<UpdateIntakeUsecase>().updateIntake(
          editing.id,
          {
            'meal': MealDBO.fromMealEntity(intake.meal),
            'quantity': intake.quantity,
          },
        );
        if (updated == null) return;
      } else {
        await locator<AddIntakeUsecase>().addIntake(intake);
        await _updateTrackedDay(intake);
      }
      if (!identical(profileBox, locator<HiveDBProvider>().intakeBox)) return;
      await locator<CustomMealDataSource>().saveCustomMeal(
        MealDBO.fromMealEntity(intake.meal),
      );

      locator<HomeBloc>().add(const LoadItemsEvent());
      locator<DiaryBloc>().add(const LoadDiaryYearEvent());
      locator<CalendarDayBloc>().add(RefreshCalendarDayEvent());

      if (!mounted) return;
      if (widget.editingIntake != null) {
        Navigator.of(context).pop();
        return;
      }
      final mealTypeLabel = _intakeTypeLabel(context, widget.intakeType);
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      // Resolve the localized message before navigating: the push below
      // removes every route (including this sheet's), so reading from
      // context afterwards would be looking up a deactivated widget.
      final addedMessage = S.of(context).quickAddAddedSnack(mealTypeLabel);
      Navigator.of(
        context,
        rootNavigator: true,
      ).pushNamedAndRemoveUntil(NavigationOptions.mainRoute, (route) => false);
      scaffoldMessenger.showSnackBar(SnackBar(content: Text(addedMessage)));
    } catch (e, st) {
      _log.severe('Quick Add save failed', e, st);
      if (!mounted) return;
      setState(() => _saving = false);
    }
  }

  IntakeEntity _buildIntake({
    required double? kcal,
    required double? carbs,
    required double? fat,
    required double? protein,
    required String title,
  }) {
    // Nutrition fields are totals for this occurrence. Only weighted entries
    // back-project those totals to per-100 nutrition.
    final old = widget.editingIntake?.meal ?? widget.initialMeal;
    final oldAmount =
        widget.editingIntake?.baseAmount ??
        (old?.hasQuickAddWeight == true
            ? double.parse(old!.mealQuantity!)
            : 100);
    final enteredWeight = _parsed(_weightController);
    final quantity = enteredWeight == null
        ? null
        : (_weightController.text == _initialWeightText &&
                  _weightUnit == _initialWeightUnit &&
                  widget.editingIntake?.quantity != null
              ? widget.editingIntake!.quantity
              : FoodAmountSelection(
                  enteredWeight,
                  FoodAmountOption.standard(_weightUnit),
                ));
    final amount = quantity?.baseAmount ?? 100.0;
    final factor = amount / 100;
    NutrientAmount? stored(
      TextEditingController c,
      double? value,
      NutrientAmount? original,
    ) {
      if (old != null && _initialText[c] == c.text) {
        return amount == oldAmount
            ? original
            : original?.scale(oldAmount / amount);
      }
      return NutrientAmount.fromNumber(value)?.scale(1 / factor);
    }

    final nutriments = MealNutrimentsEntity(
      energyKcal100: stored(
        _energyController,
        kcal,
        old?.nutriments.energyKcal100,
      ),
      carbohydrates100: stored(
        _carbsController,
        carbs,
        old?.nutriments.carbohydrates100,
      ),
      fat100: stored(_fatController, fat, old?.nutriments.fat100),
      proteins100: stored(
        _proteinController,
        protein,
        old?.nutriments.proteins100,
      ),
      sugars100: old?.nutriments.sugars100,
      saturatedFat100: old?.nutriments.saturatedFat100,
      fiber100: old?.nutriments.fiber100,
      monounsaturatedFat100: old?.nutriments.monounsaturatedFat100,
      polyunsaturatedFat100: old?.nutriments.polyunsaturatedFat100,
      transFat100: old?.nutriments.transFat100,
      cholesterol100: old?.nutriments.cholesterol100,
      sodium100: old?.nutriments.sodium100,
      potassium100: old?.nutriments.potassium100,
      magnesium100: old?.nutriments.magnesium100,
      calcium100: old?.nutriments.calcium100,
      iron100: old?.nutriments.iron100,
      zinc100: old?.nutriments.zinc100,
      phosphorus100: old?.nutriments.phosphorus100,
      vitaminA100: old?.nutriments.vitaminA100,
      vitaminC100: old?.nutriments.vitaminC100,
      vitaminD100: old?.nutriments.vitaminD100,
      vitaminB6100: old?.nutriments.vitaminB6100,
      vitaminB12100: old?.nutriments.vitaminB12100,
      niacin100: old?.nutriments.niacin100,
    );
    final meal = MealEntity(
      code: old?.code ?? IdGenerator.getUniqueID(),
      name: title,
      url: null,
      mealQuantity: enteredWeight == null ? null : amount.toString(),
      mealUnit: enteredWeight == null ? 'gml' : _weightUnit.baseUnit,
      servingQuantity: null,
      servingUnit: enteredWeight == null ? 'gml' : _weightUnit.label,
      servingSize: '',
      nutriments: nutriments,
      source: MealSourceEntity.custom,
      isQuickAdd: true,
    );
    return IntakeEntity(
      id: IdGenerator.getUniqueID(),
      quantity: quantity,
      type: widget.intakeType,
      meal: meal,
      dateTime: widget.day,
    );
  }

  Future<void> _updateTrackedDay(IntakeEntity intake) async {
    final addTrackedDay = locator<AddTrackedDayUsecase>();
    final hasTrackedDay = await addTrackedDay.hasTrackedDay(widget.day);
    if (!hasTrackedDay) {
      final kcalGoal = await locator<GetKcalGoalUsecase>().getKcalGoal(
        day: widget.day,
      );
      final macroGoal = locator<GetMacroGoalUsecase>();
      await addTrackedDay.addNewTrackedDay(
        widget.day,
        kcalGoal,
        await macroGoal.getCarbsGoal(kcalGoal),
        await macroGoal.getFatsGoal(kcalGoal),
        await macroGoal.getProteinsGoal(kcalGoal),
      );
    }
    await addTrackedDay.addDayCaloriesTracked(widget.day, intake.totalKcal);
    await addTrackedDay.addDayMacrosTracked(
      widget.day,
      carbsTracked: intake.totalCarbsGram,
      fatTracked: intake.totalFatsGram,
      proteinTracked: intake.totalProteinsGram,
    );
  }

  String _intakeTypeLabel(BuildContext context, IntakeTypeEntity type) {
    switch (type) {
      case IntakeTypeEntity.breakfast:
        return S.of(context).breakfastLabel;
      case IntakeTypeEntity.lunch:
        return S.of(context).lunchLabel;
      case IntakeTypeEntity.dinner:
        return S.of(context).dinnerLabel;
      case IntakeTypeEntity.snack:
        return S.of(context).snackLabel;
    }
  }

  @override
  Widget build(BuildContext context) {
    final usesKj = context.watch<EnergyUnitProvider>().usesKilojoules;
    final s = S.of(context);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                s.quickAddBottomSheetTitle,
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
            ),
            _field(
              controller: _titleController,
              identifier: 'quick-add-title',
              label: s.quickAddTitleHint,
              isRequired: true,
              numeric: false,
              autofocus: true,
            ),
            _field(
              controller: _energyController,
              identifier: 'quick-add-energy',
              label: usesKj
                  ? s.quickAddEnergyLabelKj
                  : s.quickAddEnergyLabelKcal,
              isRequired: false,
              numeric: true,
            ),
            _field(
              controller: _carbsController,
              identifier: 'quick-add-carbs',
              label: s.quickAddCarbsHint,
              isRequired: false,
              numeric: true,
            ),
            _field(
              controller: _fatController,
              identifier: 'quick-add-fat',
              label: s.quickAddFatHint,
              isRequired: false,
              numeric: true,
            ),
            _field(
              controller: _proteinController,
              identifier: 'quick-add-protein',
              label: s.quickAddProteinHint,
              isRequired: false,
              numeric: true,
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Semantics(
                identifier: 'quick-add-weight',
                child: TextField(
                  controller: _weightController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: CustomTextInputFormatter.doubleOnly(),
                  decoration: InputDecoration(
                    labelText: widget.onConfirm == null
                        ? s.quickAddWeightLabel
                        : s.foodAmountWeightLabel,
                    border: const OutlineInputBorder(),
                    suffixIcon: Semantics(
                      identifier: 'quick-add-weight-unit',
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<FoodAmountUnit>(
                            value: _weightUnit,
                            items: [
                              for (final u in FoodAmountUnit.values)
                                DropdownMenuItem(
                                  value: u,
                                  child: Text(u.label),
                                ),
                            ],
                            onChanged: (unit) {
                              if (unit != null) {
                                setState(() => _weightUnit = unit);
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Semantics(
              identifier: 'quick-add-submit',
              child: FilledButton(
                onPressed: _canSubmit ? _onSubmit : null,
                child: _saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        widget.editingIntake == null
                            ? s.addLabel
                            : s.buttonSaveLabel,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String identifier,
    required String label,
    required bool isRequired,
    required bool numeric,
    bool autofocus = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        identifier: identifier,
        child: TextField(
          controller: controller,
          autofocus: autofocus,
          keyboardType: numeric
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          inputFormatters: numeric
              ? CustomTextInputFormatter.doubleOnly()
              : null,
          decoration: InputDecoration(
            labelText: isRequired ? '$label *' : label,
            border: const OutlineInputBorder(),
          ),
        ),
      ),
    );
  }
}
