import 'package:opennutritracker/generated/l10n.dart';

/// Normalizes common household units using the English ARB plural forms.
/// Persisted food labels stay unchanged; descriptive modifier prose such as
/// "cup, sliced" is preserved rather than partially normalized.
String localizeServingLabel(S s, String label) {
  final match = _servingLabelPattern.firstMatch(label.trim());
  if (match == null) return label;
  final amountText = match.group(1)!;
  final amount = num.tryParse(amountText.replaceAll(',', '.'));
  if (amount == null) return label;
  final localizedUnit = _localizedUnit(
    s,
    match.group(2)!.trim().toLowerCase(),
    amount,
  );
  if (localizedUnit == null) return label;
  final weightSuffix = match.group(3);
  return weightSuffix != null
      ? '$amountText $localizedUnit $weightSuffix'
      : '$amountText $localizedUnit';
}

/// "`<amount> <unit words> (weight)`" — the unit part deliberately excludes
/// commas so descriptive modifiers ("cup, sliced") don't match.
final _servingLabelPattern = RegExp(
  r'^(\d+(?:[.,]\d+)?)\s+([A-Za-z ]+?)\s*(\(.*\))?$',
);

String? _localizedUnit(S s, String unit, num count) {
  switch (unit) {
    case 'portion':
    case 'portions':
      return s.measureUnitPortion(count);
    case 'serving':
    case 'servings':
      return s.measureUnitServing(count);
    case 'cup':
    case 'cups':
      return s.measureUnitCup(count);
    case 'tablespoon':
    case 'tablespoons':
    case 'tbsp':
      return s.measureUnitTablespoon(count);
    case 'teaspoon':
    case 'teaspoons':
    case 'tsp':
      return s.measureUnitTeaspoon(count);
    case 'slice':
    case 'slices':
      return s.measureUnitSlice(count);
    case 'piece':
    case 'pieces':
      return s.measureUnitPiece(count);
    case 'package':
    case 'packages':
      return s.measureUnitPackage(count);
    case 'can':
    case 'cans':
      return s.measureUnitCan(count);
    case 'bottle':
    case 'bottles':
      return s.measureUnitBottle(count);
    case 'bar':
    case 'bars':
      return s.measureUnitBar(count);
    case 'egg':
    case 'eggs':
      return s.measureUnitEgg(count);
    default:
      return null;
  }
}
