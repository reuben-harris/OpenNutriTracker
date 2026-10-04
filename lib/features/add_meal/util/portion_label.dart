library;

/// A leading count: "1 slice", "0.5 cup", "1,5 l".
final _leadingCount = RegExp(r'^\s*\d+(?:[.,]\d+)?\s*');

/// A trailing parenthetical carrying the weight: "1 slice (38 g)".
final _trailingWeight = RegExp(r'\s*\([^)]*\)\s*$');

/// What is left when a description names no household measure at all — a
/// bare weight or volume. Matched whole, so "cup" survives and "g" does
/// not.
final _bareUnit = RegExp(
  r'^(?:g|kg|ml|l|lb|oz|fl\.?\s?oz|g/ml|portion|serving)$',
  caseSensitive: false,
);

/// Anything with a letter in it. A description reduced to punctuation or
/// digits names nothing.
final _hasLetter = RegExp(r'\p{L}', unicode: true);

/// Long enough for "cup, sliced" and short enough not to reopen #824, where
/// this row overflowed by 65px because one field took the width it wanted.
/// The dropdown sizes itself to its widest item, so this bound is a layout
/// constraint rather than a stylistic one — a label that would blow the row
/// out is worth losing, since "Serving" is still correct underneath it.
const maxHouseholdPortionLabel = 16;

String? householdPortionLabel(
  String? servingSize, {
  required String languageCode,
  bool textIsLocalized = false,
}) {
  // English, or a translation a human has verified. Both mean the same
  // thing here — the text is in the reader's language — and nothing else
  // does, because "1 Scheibe" and "1 slice" are indistinguishable as
  // strings once they are on the entity.
  if (!textIsLocalized && languageCode != 'en') return null;
  if (servingSize == null) return null;

  final withoutWeight = servingSize.replaceFirst(_trailingWeight, '');
  final label = withoutWeight.replaceFirst(_leadingCount, '').trim();

  if (label.isEmpty) return null;
  // "30 g" reduces to "g", and OFF's "1 portion" to "portion". Neither says
  // more than the word already on the dropdown.
  if (_bareUnit.hasMatch(label)) return null;
  if (!_hasLetter.hasMatch(label)) return null;
  if (label.length > maxHouseholdPortionLabel) return null;

  return label;
}
