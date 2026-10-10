import 'package:opennutritracker/core/search/food_search_ranker.dart';
import 'package:opennutritracker/features/add_meal/presentation/widgets/food_search_view.dart';
import 'package:flutter/material.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/presentation/add_meal_type.dart';
import 'package:opennutritracker/features/add_meal/presentation/bloc/add_meal_bloc.dart';
import 'package:opennutritracker/features/add_meal/presentation/screens/bulk_add_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:opennutritracker/features/add_meal/presentation/widgets/meal_item_card.dart';
import 'package:opennutritracker/features/add_meal/presentation/widgets/quick_add_bottom_sheet.dart';
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
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    _addMealBloc.close();
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
          Semantics(
            identifier: 'add-meal-quick-add',
            child: TextButton(
              onPressed: _onQuickAddPressed,
              child: Text(S.of(context).quickAddCardLabel),
            ),
          ),
          BlocBuilder<AddMealBloc, AddMealState>(
            bloc: _addMealBloc,
            builder: (BuildContext context, AddMealState state) {
              if (state is AddMealLoadedState) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Semantics(
                      identifier: 'add-meal-bulk-add',
                      child: IconButton(
                        onPressed: () =>
                            _onBulkAddPressed(state.usesImperialUnits),
                        icon: const Icon(Icons.playlist_add),
                        tooltip: S.of(context).bulkAddTitle,
                      ),
                    ),
                    Semantics(
                      identifier: 'add-meal-custom-add',
                      child: IconButton(
                        onPressed: () =>
                            _onCustomAddButtonPressed(state.usesImperialUnits),
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ),
                  ],
                );
              }
              return const SizedBox();
            },
          ),
        ],
      ),
      body: BlocBuilder<AddMealBloc, AddMealState>(bloc: _addMealBloc, builder: (context, state) {
        final imperial = state is AddMealLoadedState && state.usesImperialUnits;
        return FoodSearchView(
          itemBuilder: (context, meal) => MealItemCard(key: ValueKey(foodIdentity(meal)),
            day: _day, mealEntity: meal, addMealType: _mealType, usesImperialUnits: imperial),
          onBarcodePressed: (barcode) => _onBarcodeIconPressed(barcode),
          onCreateCustomFood: () => _onCustomAddButtonPressed(imperial),
        );
      }),
    );
  }

  void _onBarcodeIconPressed([String? barcode]) {
    Navigator.of(context).pushNamed(
      NavigationOptions.scannerRoute,
      arguments: ScannerScreenArguments(_day, _mealType.getIntakeType(), initialBarcode: barcode),
    );
  }

  void _onBulkAddPressed(bool usesImperialUnits) {
    Navigator.of(context).pushNamed(
      NavigationOptions.bulkAddRoute,
      arguments: BulkAddScreenArguments(
        _mealType.getIntakeType(),
        _day,
        usesImperialUnits,
      ),
    );
  }

  void _onQuickAddPressed() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) =>
          QuickAddBottomSheet(intakeType: _mealType.getIntakeType(), day: _day),
    );
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

  AddMealScreenArguments(this.mealType, this.day);
}
