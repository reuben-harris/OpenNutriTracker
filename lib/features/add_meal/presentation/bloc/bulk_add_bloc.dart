import 'package:opennutritracker/core/food_amount/food_amount.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logging/logging.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/meal_photo_interpreter.dart';
import 'package:opennutritracker/features/add_meal/domain/usecase/read_meal_photo_usecase.dart';
import 'package:opennutritracker/features/add_meal/domain/usecase/read_meal_text_usecase.dart';
import 'package:opennutritracker/features/add_meal/domain/usecase/resolve_parsed_meals_usecase.dart';
import 'package:opennutritracker/features/add_meal/util/meal_text_parser.dart';
import 'package:opennutritracker/features/add_meal/util/portion_match.dart';

part 'bulk_add_event.dart';
part 'bulk_add_state.dart';

/// The shape an amount has to have: no scientific notation, no sign, at most
/// two decimals. The same shape the manual-entry quantity field enforces
/// (`meal_detail_bottom_sheet.dart`), so the bulk path accepts exactly what
/// manual entry does.
///
/// Kept here rather than on the screen because three things have to agree
/// about it and only one of them is a widget: the field's input formatter,
/// [BulkAddBloc._amountText] — which rounds every prefilled amount to satisfy
/// it — and [BulkAddRow.quantityError], which reports what fails it.
final bulkAddQuantityPattern = RegExp(r'^\d+([.,]\d{0,2})?$');

/// Matches the manual-entry upper bound.
const bulkAddMaxQuantity = 10000;

/// Why a row's amount cannot be written, in terms the user can act on.
///
/// The three arrived at the screen as one message naming the field and
/// nothing else, so "0", "99999" and "1.234" all read as `Rice: Quantity`.
/// They are separated here rather than at the render site because the render
/// site would then have to re-derive which of them happened. #1013.
enum BulkAddQuantityError {
  /// Not a number this screen accepts: empty, or carrying more decimals than
  /// the field allows. The one failure the UI never stated a rule for.
  malformed,

  /// Zero or less. Nothing to log.
  tooSmall,

  /// Above [bulkAddMaxQuantity].
  tooLarge,
}

/// One editable row on the review screen.
///
/// Holds the user's edits separately from what the resolver produced, so
/// re-parsing or picking a different candidate never silently discards a
/// quantity the user typed.
class BulkAddRow extends Equatable {
  final ResolvedMealItem resolved;

  /// Index into [ResolvedMealItem.candidates], possibly changed by the user
  /// via the candidate picker.
  final int selectedIndex;

  /// As typed. Kept as text rather than a double so the field can hold an
  /// in-progress value ("1," / "") without the row deciding it is invalid
  /// mid-keystroke — validation happens on submit.
  final String amountText;
  final String unit;

  /// Rows the user chose to leave out. Skipped rather than removed, so the
  /// decision stays visible and reversible until the batch is logged.
  final bool skipped;

  /// Set once the user picks a unit from the dropdown themselves, which
  /// settles [amountNeedsCheck] — they have made the call it was asking for.
  final bool unitChosenByUser;

  /// Set once the user types in the amount field.
  final bool amountEditedByUser;

  /// Editing an unresolved count cannot implicitly turn it into a weight.
  final bool requiresUnitChoice;

  /// True when the batch this row belongs to was read off a photograph.
  ///
  /// Copied from [BulkAddLoadedState.source] when the row is built, because
  /// one flag on the row reads it: a photo-path portion miss stays quiet
  /// ([portionKeyMissed]). The state already tells the user a machine
  /// identified the food from a picture, with a banner over every row; a
  /// second marker on the rows would draw the eye to the smaller of the two
  /// judgements. #1159.
  final bool fromPhoto;

  /// True while the amount and unit are still what the bloc derived, so
  /// re-deriving them against a newly picked candidate cannot overwrite
  /// anything the user typed or chose.
  bool get isPristine => !unitChosenByUser && !amountEditedByUser;

  const BulkAddRow({
    required this.resolved,
    required this.selectedIndex,
    required this.amountText,
    required this.unit,
    this.skipped = false,
    this.unitChosenByUser = false,
    this.amountEditedByUser = false,
    this.requiresUnitChoice = false,
    this.fromPhoto = false,
  });

  bool get isResolved => resolved.isResolved;

  /// True when a match was found but is weak enough to show a caution.
  /// Only meaningful for the resolver's own first choice — once the user
  /// picks a candidate themselves, the machine's doubt is no longer
  /// relevant and the flag clears.
  bool get isLowConfidence =>
      resolved.isLowConfidence && selectedIndex == resolved.selectedIndex;

  MealEntity? get meal =>
      isResolved ? resolved.candidates[selectedIndex] : null;

  List<FoodAmountOption> get options {
    if (meal == null) return [];
    final result = foodAmountOptions(meal!);
    final selected = option;
    if (selected != null && !result.any((o) => o.unit == selected.unit)) {
      result.add(selected);
    }
    return result;
  }

  FoodAmountOption? get option =>
      meal == null ? null : resolveFoodAmountOption(meal!, unit);

  FoodAmountSelection? get selection {
    if (meal == null || amountNeedsCheck) return null;
    final amount = double.tryParse(amountText.trim().replaceAll(',', '.'));
    return amount == null ? null : resolveFoodAmount(amount, unit, meal!);
  }

  /// Candidate changes must revalidate even a unit explicitly chosen earlier.
  bool get amountNeedsCheck =>
      isResolved &&
      (option == null ||
          requiresUnitChoice ||
          (!unitChosenByUser &&
              resolved.parsed.quantity != null &&
              ((resolved.parsed.unit == null && !option!.isNamed) ||
                  portionKeyMissed)));

  /// True when the model named a portion, this food has portions to choose
  /// from, and neither that word nor the query words is one of them.
  ///
  /// Each conjunct earns its place. **A key was given**: the deterministic
  /// parser never sets one, so a typed "handful" that misses is
  /// indistinguishable from no word and cannot be marked — that asymmetry is
  /// recorded on #1159, not fixed here. **The food has portions**: measured
  /// over 999 live calls, the clause without this gate fired on 40 of 48
  /// German rows, almost every one a record with no portion rows at all —
  /// there the dropdown offers `g`, `oz`, `g/ml` and nothing that means *a
  /// slice*, so the warning would point at a control that cannot answer it,
  /// the #973 anti-pattern; gated, 3 of 48. An unavailable lookup counts as
  /// no portions too: a transient outage says nothing about the food and
  /// must not raise a flag the next search would clear. **A count was
  /// stated**: `_initialUnit` consults the word only under one, so without
  /// it there was no match to miss. **Nothing matched**: a tie is a hit, and
  /// the query words are tried after the key exactly as `_initialUnit` tries
  /// them, so this asks what that method asked and nothing more. **Not a
  /// photo read**: most survey records the app can see carry no size row,
  /// so a photo warning would fire on most photo rows and become wallpaper;
  /// the batch banner is the marker there.
  ///
  /// Cleared by `unitChosenByUser` like the rest of [amountNeedsCheck]:
  /// picking a unit is the answer the warning asks for, and the dropdown
  /// holds every portion the food has.
  bool get portionKeyMissed {
    final key = resolved.parsed.portion;
    final food = meal;
    if (key == null || food == null || fromPhoto) return false;
    if (resolved.parsed.quantity == null) return false;
    if (food.portionsUnavailable || food.portions.isEmpty) return false;
    return matchPortionToKey(key, food.portions) == null &&
        matchPortionToQuery(resolved.parsed.query, food.portions) == null;
  }

  /// An explicit neutral default is provisional until the user edits it.
  bool get amountIsProvisional =>
      !amountEditedByUser &&
      isResolved &&
      resolved.parsed.quantity == null &&
      !options.any((o) => o.unit == 'serving');

  /// Invalid numeric text is reported on submit, rather than silently skipped.
  bool get willBeLogged => isResolved && !skipped && !amountNeedsCheck;

  /// What is wrong with [amountText], or null when the row can be written.
  ///
  /// Deliberately **not** consulted by [willBeLogged]. A row the user
  /// mistyped is handed back to them to fix; dropping it from the batch
  /// instead would log the rest and say nothing about the one that was
  /// meant to be there.
  ///
  /// Asked on submit rather than on every keystroke — [amountText] is text
  /// precisely so that a half-typed "1," is not called wrong mid-edit.
  BulkAddQuantityError? get quantityError {
    final text = amountText.trim();
    final quantity = double.tryParse(text.replaceAll(',', '.'));
    // Shape first, because the other two need a number to compare against a
    // bound and "" and "1.234" do not supply one. The parse is checked
    // beside the pattern rather than after it, so that whatever the write
    // would actually parse is what the bounds below are read from.
    if (!bulkAddQuantityPattern.hasMatch(text) || quantity == null) {
      return BulkAddQuantityError.malformed;
    }
    if (quantity <= 0) return BulkAddQuantityError.tooSmall;
    if (quantity > bulkAddMaxQuantity) return BulkAddQuantityError.tooLarge;
    return null;
  }

  BulkAddRow copyWith({
    int? selectedIndex,
    String? amountText,
    String? unit,
    bool? skipped,
    bool? unitChosenByUser,
    bool? amountEditedByUser,
    bool? requiresUnitChoice,
  }) => BulkAddRow(
    resolved: resolved,
    selectedIndex: selectedIndex ?? this.selectedIndex,
    amountText: amountText ?? this.amountText,
    unit: unit ?? this.unit,
    skipped: skipped ?? this.skipped,
    unitChosenByUser: unitChosenByUser ?? this.unitChosenByUser,
    amountEditedByUser: amountEditedByUser ?? this.amountEditedByUser,
    requiresUnitChoice: requiresUnitChoice ?? this.requiresUnitChoice,
    fromPhoto: fromPhoto,
  );

  @override
  List<Object?> get props => [
    resolved.parsed.query,
    selectedIndex,
    amountText,
    unit,
    skipped,
    unitChosenByUser,
    amountEditedByUser,
    requiresUnitChoice,
    fromPhoto,
  ];
}

class BulkAddBloc extends Bloc<BulkAddEvent, BulkAddState> {
  final log = Logger('BulkAddBloc');

  final ResolveParsedMealsUseCase _resolveParsedMealsUseCase;
  final ReadMealTextUseCase _readMealTextUseCase;
  final ReadMealPhotoUseCase _readMealPhotoUseCase;

  /// Which read is current. Bumped by every parse, photo read and cancel, and
  /// compared after every await, so a result that lands for an earlier
  /// attempt is dropped. `emit.isDone` cannot do this: it only answers for a
  /// closed bloc, and a cancelled wait leaves the bloc very much open.
  int _attempt = 0;

  /// True when [attempt] is no longer the read the screen is waiting on.
  bool _superseded(int attempt) => attempt != _attempt;

  BulkAddBloc(
    this._resolveParsedMealsUseCase,
    this._readMealTextUseCase,
    this._readMealPhotoUseCase,
  ) : super(const BulkAddInitial()) {
    on<ParseBulkTextEvent>(_onParse);
    on<ReadMealPhotoEvent>(_onReadPhoto);
    on<ReadMealPhotoFailedEvent>(
      (event, emit) => emit(BulkAddPhotoErrorState(event.error)),
    );
    on<CancelBulkReadEvent>(_onCancel);
    on<ChangeRowCandidateEvent>(_onChangeCandidate);
    on<ChangeRowAmountEvent>(_onChangeAmount);
    on<ChangeRowUnitEvent>(_onChangeUnit);
    on<ToggleRowSkippedEvent>(_onToggleSkipped);
  }

  Future<void> _onParse(
    ParseBulkTextEvent event,
    Emitter<BulkAddState> emit,
  ) async {
    // Emitted before the read, not after: with a key configured this waits
    // on a network round trip, and a screen that does nothing for two
    // seconds reads as broken.
    final attempt = ++_attempt;
    emit(BulkAddLoadingState(attempt: attempt));

    final reading = await _readMealTextUseCase.read(
      event.text,
      localeCode: event.localeCode,
    );
    if (emit.isDone || _superseded(attempt)) return;

    await _resolveAndEmit(
      reading.result,
      emit,
      attempt: attempt,
      usesImperialUnits: event.usesImperialUnits,
      source: reading.usedModel
          ? BulkAddReadSource.model
          : BulkAddReadSource.parser,
      modelFailure: reading.modelFailure,
    );
  }

  /// A photo has no deterministic reader underneath it, so unlike the text
  /// path every failure here reaches the user. Saying "that did not work" is
  /// the honest outcome; quietly emitting no rows would leave the screen
  /// looking broken with nothing to act on.
  Future<void> _onReadPhoto(
    ReadMealPhotoEvent event,
    Emitter<BulkAddState> emit,
  ) async {
    final attempt = ++_attempt;
    emit(BulkAddLoadingState(attempt: attempt));

    final reading = await _readMealPhotoUseCase.read(
      event.photo,
      localeCode: event.localeCode,
    );
    if (emit.isDone || _superseded(attempt)) return;

    switch (reading) {
      case MealPhotoUnavailable():
        emit(const BulkAddPhotoErrorState(BulkAddPhotoError.unavailable));
      case MealPhotoFailed(:final failure):
        emit(
          BulkAddPhotoErrorState(switch (failure) {
            MealPhotoFailure.auth => BulkAddPhotoError.auth,
            // The provider will refuse this picture every time, so it lands
            // on "try another photo" rather than on "try again".
            MealPhotoFailure.rejectedImage => BulkAddPhotoError.unreadable,
            MealPhotoFailure.unsupported => BulkAddPhotoError.unsupported,
            MealPhotoFailure.insecureDestination =>
              BulkAddPhotoError.insecureDestination,
            MealPhotoFailure.billing => BulkAddPhotoError.billing,
            MealPhotoFailure.transient => BulkAddPhotoError.transient,
          }),
        );
      case MealPhotoRead(:final result):
        // An empty list is an answer, not a failure: the model looked and
        // found no food. It lands on the same "nothing to log" message the
        // text path uses rather than on an error, because nothing went
        // wrong — the photo just was not of a meal.
        await _resolveAndEmit(
          result,
          emit,
          attempt: attempt,
          usesImperialUnits: event.usesImperialUnits,
          source: BulkAddReadSource.photo,
        );
    }
  }

  /// Leaves the loading state and orphans the read in flight.
  ///
  /// Bumping [_attempt] is the whole mechanism: the handler still awaiting
  /// the read compares against it afterwards and returns without emitting.
  /// Back to [BulkAddInitial] rather than to the previous rows, because the
  /// text field still holds what was typed and a Search away from trying
  /// again is the state the user was in before they tapped it. Only while
  /// loading — a cancel that lands after the rows have does nothing, so a
  /// tap racing a late result cannot wipe rows the user is already reading.
  void _onCancel(CancelBulkReadEvent event, Emitter<BulkAddState> emit) {
    if (state is! BulkAddLoadingState) return;
    _attempt++;
    emit(const BulkAddInitial());
  }

  /// Shared by both readers: resolve whatever was extracted against the food
  /// database and emit the review rows. Which reader produced the items only
  /// changes [source] — everything downstream of here treats all three the
  /// same, which is what keeps the review screen honest about all of them.
  Future<void> _resolveAndEmit(
    MealTextParseResult parsed,
    Emitter<BulkAddState> emit, {
    required int attempt,
    required bool usesImperialUnits,
    required BulkAddReadSource source,
    MealTextModelFailure? modelFailure,
  }) async {
    if (parsed.items.isEmpty) {
      // Nothing usable. The parser's own errors still go through so the
      // user is told why, rather than the screen just doing nothing.
      emit(
        BulkAddLoadedState(
          rows: const [],
          parseErrors: parsed.errors,
          usesImperialUnits: usesImperialUnits,
          source: source,
          modelFailure: modelFailure,
        ),
      );
      return;
    }

    try {
      final resolved = await _resolveParsedMealsUseCase.resolve(parsed.items);
      if (emit.isDone || _superseded(attempt)) return;

      emit(
        BulkAddLoadedState(
          rows: [
            for (final item in resolved)
              BulkAddRow(
                resolved: item,
                selectedIndex: item.selectedIndex,
                amountText: _initialAmount(
                  item.parsed,
                  item.selected,
                  usesImperialUnits,
                ),
                unit: _initialUnit(
                  item.parsed,
                  item.selected,
                  usesImperialUnits,
                ),
                fromPhoto: source == BulkAddReadSource.photo,
              ),
          ],
          parseErrors: parsed.errors,
          usesImperialUnits: usesImperialUnits,
          source: source,
          modelFailure: modelFailure,
        ),
      );
    } catch (e, stackTrace) {
      log.severe('Bulk resolution failed', e, stackTrace);
      if (emit.isDone || _superseded(attempt)) return;
      emit(const BulkAddErrorState());
    }
  }

  /// The parser leaves quantity null when the user stated none. Fall back to
  /// the same defaults the meal-detail screen already applies, so a bulk row
  /// and a hand-added row of the same food start from the same number.
  String _initialAmount(
    ParsedMealItem parsed,
    MealEntity? meal,
    bool usesImperialUnits,
  ) {
    final parsedQuantity = parsed.quantity;
    if (parsedQuantity != null) return _amountText(parsedQuantity);

    final serving = meal == null
        ? null
        : resolveFoodAmountOption(meal, 'serving');
    if (serving != null) return _amountText(serving.factor);
    return usesImperialUnits ? '1' : '100';
  }

  String _initialUnit(
    ParsedMealItem parsed,
    MealEntity? meal,
    bool usesImperialUnits,
  ) {
    if (meal == null) return parsed.unit ?? (usesImperialUnits ? 'oz' : 'g/ml');
    final stated = parsed.unit;
    if (stated != null && stated != 'serving') {
      return resolveFoodAmountOption(meal, stated)?.unit ?? stated;
    }
    if (parsed.quantity != null) {
      final named =
          matchPortionToKey(parsed.portion, meal.portions) ??
          matchPortionToQuery(parsed.query, meal.portions);
      if (named != null) return 'portion:${meal.portions[named].id}';
      final options = foodAmountOptions(meal);
      final serving = options.where((o) => o.unit == 'serving').firstOrNull;
      if (serving != null) return serving.unit;
      final portion = options
          .where((o) => o.unit.startsWith('portion:'))
          .firstOrNull;
      if (portion != null) return portion.unit;
      // A count is not a weight. Leave its request unresolved until corrected.
      return 'serving';
    }
    final serving = resolveFoodAmountOption(meal, 'serving');
    if (serving != null) return serving.baseUnit;
    return usesImperialUnits
        ? (meal.isLiquid ? 'fl oz' : 'oz')
        : defaultFoodAmount(meal).option.unit;
  }

  /// Formats a quantity for the amount field, which accepts at most two
  /// decimals — [bulkAddQuantityPattern] is both the submit check and the
  /// field's input formatter. A converted imperial quantity has
  /// many more: `1 lb` is 453.59237 g. Prefilling that verbatim produced a row
  /// the submit check refused, with a message naming only the field, and
  /// because that check aborts the batch, one such row blocked every correct
  /// row beside it. The pattern is anchored, so the formatter then rejected
  /// every edit too and the field blanked on the first keystroke. Rounding
  /// here is what keeps the prefill and the check in step.
  ///
  /// The floor is the same concern from the other end: a positive quantity
  /// below 0.005 would round to zero, which the check rejects for being
  /// non-positive.
  static String _amountText(double value) {
    final rounded = double.parse(value.toStringAsFixed(2));
    final quantity = rounded <= 0 && value > 0 ? 0.01 : rounded;
    return quantity == quantity.roundToDouble()
        ? quantity.toInt().toString()
        : quantity.toString();
  }

  void _onChangeCandidate(
    ChangeRowCandidateEvent event,
    Emitter<BulkAddState> emit,
  ) {
    final current = state;
    final imperial = current is BulkAddLoadedState && current.usesImperialUnits;

    _updateRow(event.rowIndex, emit, (row) {
      final moved = row.copyWith(selectedIndex: event.candidateIndex);
      // A different food means different defaults. Re-derive them, or the
      // row keeps the previous candidate's unit — picking a countable
      // record after an uncountable one cleared the "check the unit"
      // warning while the amount stayed a weight, which is the #622
      // failure again with the warning switched off. Only for a pristine
      // row: anything the user typed or chose outranks a default.
      if (!moved.isPristine) return moved;
      return moved.copyWith(
        amountText: _initialAmount(row.resolved.parsed, moved.meal, imperial),
        unit: _initialUnit(row.resolved.parsed, moved.meal, imperial),
      );
    });
  }

  void _onChangeAmount(ChangeRowAmountEvent event, Emitter<BulkAddState> emit) {
    _updateRow(
      event.rowIndex,
      emit,
      (row) => row.copyWith(
        amountText: event.amountText,
        amountEditedByUser: true,
        requiresUnitChoice: row.requiresUnitChoice || row.amountNeedsCheck,
      ),
    );
  }

  void _onChangeUnit(ChangeRowUnitEvent event, Emitter<BulkAddState> emit) {
    _updateRow(
      event.rowIndex,
      emit,
      // Picking a unit answers the question `amountNeedsCheck` was asking,
      // so the row stops asking it.
      (row) => row.copyWith(
        unit: event.unit,
        unitChosenByUser: true,
        requiresUnitChoice: false,
      ),
    );
  }

  void _onToggleSkipped(
    ToggleRowSkippedEvent event,
    Emitter<BulkAddState> emit,
  ) {
    _updateRow(
      event.rowIndex,
      emit,
      (row) => row.copyWith(skipped: !row.skipped),
    );
  }

  void _updateRow(
    int index,
    Emitter<BulkAddState> emit,
    BulkAddRow Function(BulkAddRow) change,
  ) {
    final current = state;
    if (current is! BulkAddLoadedState) return;
    if (index < 0 || index >= current.rows.length) return;

    final rows = [...current.rows];
    rows[index] = change(rows[index]);
    emit(current.copyWith(rows: rows));
  }
}
