import 'package:opennutritracker/core/food_amount/food_information.dart';
import 'package:opennutritracker/core/food_amount/log_food_amount.dart';
import 'package:opennutritracker/core/search/food_search_engine.dart';
import 'package:opennutritracker/features/add_meal/presentation/bloc/food_search_controller.dart';
import 'package:opennutritracker/core/search/food_search_ranker.dart';
import 'package:opennutritracker/features/add_meal/presentation/widgets/food_search_view.dart';
import 'package:flutter/material.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/presentation/add_meal_type.dart';
import 'package:opennutritracker/features/add_meal/presentation/bloc/add_meal_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:opennutritracker/features/add_meal/presentation/widgets/meal_item_card.dart';
import 'package:opennutritracker/features/edit_meal/presentation/edit_meal_screen.dart';
import 'package:opennutritracker/features/scanner/scanner_screen.dart';
import 'package:opennutritracker/generated/l10n.dart';

class AddMealScreen extends StatefulWidget {
  const AddMealScreen({super.key});

  @override
  State<AddMealScreen> createState() => _AddMealScreenState();
}

class _AddMealScreenState extends State<AddMealScreen> {
  late AddMealType _mealType;
  late DateTime _day;

  late AddMealBloc _addMealBloc;
  FoodSearchController? _search;
  bool _handedOff = false;

  @override
  void initState() {
    _addMealBloc = locator<AddMealBloc>()..add(InitializeAddMealEvent());
    super.initState();
  }

  @override
  void didChangeDependencies() {
    final args =
        ModalRoute.of(context)?.settings.arguments as AddMealScreenArguments;
    _mealType = args.mealType;
    _day = args.day;
    _search ??=
        args.search ?? FoodSearchController(locator<FoodSearchEngine>());
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    _addMealBloc.close();
    if (!_handedOff) _search?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Let the keyboard overlay the results rather than compress the body.
      // In landscape the space above the keyboard is shorter than the pinned
      // search bar + tab bar, which otherwise overflows (issue #165 testing).
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text(_mealType.getTypeName(context)),
        actions: [
          BlocBuilder<AddMealBloc, AddMealState>(
            bloc: _addMealBloc,
            builder: (BuildContext context, AddMealState state) {
              if (state is AddMealLoadedState) {
                return Semantics(
                  identifier: 'add-meal-custom-add',
                  child: IconButton(
                    onPressed: () =>
                        _onCustomAddButtonPressed(state.usesImperialUnits),
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                );
              }
              return const SizedBox();
            },
          ),
        ],
      ),
      body: BlocBuilder<AddMealBloc, AddMealState>(
        bloc: _addMealBloc,
        builder: (context, state) {
          final imperial =
              state is AddMealLoadedState && state.usesImperialUnits;
          return FoodSearchView(
            controller: _search,
            itemBuilder: (context, meal) => MealItemCard(
              key: ValueKey(foodIdentity(meal)),
              mealEntity: meal,
              onSelected: _selectFood,
              onInfo: () async {
                final navigator = Navigator.of(context);
                final saved = await showFoodInformation(
                  context,
                  meal: meal,
                  day: _day,
                  type: _mealType.getIntakeType(),
                  imperial: imperial,
                );
                if (saved && mounted) {
                  _handedOff = true;
                  navigator.pop();
                  await _search!.close();
                }
              },
            ),
            onBarcodePressed: (barcode) => _onBarcodeIconPressed(barcode),
            onCreateCustomFood: () => _onCustomAddButtonPressed(imperial),
          );
        },
      ),
    );
  }

  Future<void> _selectFood(MealEntity meal) async {
    if (_handedOff) return;
    final navigator = Navigator.of(context);
    final search = _search!;
    final args = AddMealScreenArguments(_mealType, _day, search: search);
    _handedOff = true;
    navigator.pop();
    final saved = await logFoodAmount(
      navigator.context,
      meal: meal,
      day: _day,
      type: _mealType.getIntakeType(),
    );
    if (!saved && navigator.mounted) {
      navigator.pushNamed(NavigationOptions.addMealRoute, arguments: args);
    } else {
      await search.close();
    }
  }

  Future<void> _onBarcodeIconPressed([String? barcode]) async {
    final selected = await Navigator.of(context).pushNamed(
      NavigationOptions.scannerRoute,
      arguments: ScannerScreenArguments(
        _day,
        _mealType.getIntakeType(),
        initialBarcode: barcode,
      ),
    );
    if (selected is MealEntity && mounted) await _selectFood(selected);
  }

  void _onCustomAddButtonPressed(bool usesImperialUnits) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(S.of(context).createCustomDialogTitle),
          content: Text(S.of(context).createCustomDialogContent),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(), // close dialog
              child: Text(S.of(context).dialogCancelLabel),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                _openEditMealScreen(usesImperialUnits);
              },
              child: Text(S.of(context).buttonYesLabel),
            ),
          ],
        );
      },
    );
  }

  void _openEditMealScreen(bool usesImperialUnits) {
    Navigator.of(context).pushNamed(
      NavigationOptions.editMealRoute,
      arguments: EditMealScreenArguments(
        _day,
        MealEntity.empty(),
        _mealType.getIntakeType(),
        usesImperialUnits,
      ),
    );
  }
}

class AddMealScreenArguments {
  final AddMealType mealType;
  final DateTime day;
  final FoodSearchController? search;

  AddMealScreenArguments(this.mealType, this.day, {this.search});
}
