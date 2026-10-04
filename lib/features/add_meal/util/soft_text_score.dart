library;

/// Shortest prefix agreement that counts as a partial match at all, unless
/// one of the tokens is shorter than this — `Ei`/`Eier` must still match,
/// while `apple`/`apricot` (which agree on `ap`) must not.
const _minPrefix = 3;

/// Characters from scripts that do not separate words with spaces. A
/// Unicode script property rather than a vocabulary list, so it does not
/// grow when a language is added.
final _unspacedScript = RegExp(
  r'[\p{Script=Han}\p{Script=Hiragana}\p{Script=Katakana}'
  r'\p{Script=Hangul}]',
  unicode: true,
);

/// The character pairs in [text], or the text itself when it is too short
/// to have any.
Set<String> _bigrams(String text) {
  if (text.length < 2) return {text};
  return {for (var i = 0; i < text.length - 1; i++) text.substring(i, i + 2)};
}

/// How far [a] and [b] agree, 0.0-1.0. 1.0 only for an exact match; a
/// suffix difference costs a little rather than everything.
double tokenSimilarity(String a, String b) {
  if (a == b) return 1.0;

  // Chinese, Japanese and Korean write without spaces, so [tokenize]
  // hands the whole phrase over as one token and the shared-prefix rule
  // below reads it as a single long word. That scored `鸡蛋` against
  // `土鸡蛋` — a superstring of the query — at exactly 0.0, and it is why
  // a `zh` search could miss the product it was looking at.
  //
  // Character bigrams compare these the way whitespace tokens compare in
  // Latin scripts: `鸡蛋` and `土鸡蛋` share one pair out of three, so they
  // agree rather than disagree. It also makes a leading counter harmless —
  // `个鸡蛋` still matches `鸡蛋` — which is what removes any need for a
  // list of measure words.
  if (_unspacedScript.hasMatch(a) || _unspacedScript.hasMatch(b)) {
    final aGrams = _bigrams(a);
    final bGrams = _bigrams(b);
    final shared = aGrams.intersection(bGrams).length;
    if (shared == 0) return 0.0;
    return 2 * shared / (aGrams.length + bGrams.length);
  }

  final shorter = a.length < b.length ? a.length : b.length;
  final longer = a.length > b.length ? a.length : b.length;

  var shared = 0;
  while (shared < shorter && a.codeUnitAt(shared) == b.codeUnitAt(shared)) {
    shared++;
  }

  // The guard relaxes for tokens shorter than [_minPrefix] so genuinely
  // short words ("Ei", "ox") are not excluded by their own length.
  final required = _minPrefix < shorter ? _minPrefix : shorter;
  if (shared < required) return 0.0;

  return shared / longer;
}

/// [token]'s best agreement with any of [against]; 0.0 when there is none.
double _bestAgreement(String token, Set<String> against) =>
    against.fold(0.0, (best, other) {
      final similarity = tokenSimilarity(token, other);
      return similarity > best ? similarity : best;
    });

/// Soft Dice: every token on each side contributes its best agreement with
/// the other side, over the total token count.
///
/// The symmetry is what keeps a long branded name from winning on a short
/// query. Scoring only the query's tokens would rank `Cadbury Creme Eggs`
/// (which contains `eggs` exactly, 1.0) above `Egg` (0.75) — the opposite
/// of what the user meant. Counting the record's unmatched tokens too
/// drops the branded name to 0.5 and puts the plain food first.
double _softDice(Set<String> textTokens, Set<String> queryTokens) {
  if (textTokens.isEmpty || queryTokens.isEmpty) return 0.0;

  double bestSum(Set<String> from, Set<String> against) =>
      from.fold(0.0, (sum, token) => sum + _bestAgreement(token, against));

  final matched =
      bestSum(queryTokens, textTokens) + bestSum(textTokens, queryTokens);
  return matched / (queryTokens.length + textTokens.length);
}

/// The tokens of [text]: lower-cased, split on anything that is not a
/// letter or a digit, in the order they appear. Empty for null or blank.
Set<String> tokenize(String? text) {
  final normalized =
      text?.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ') ?? '';
  if (normalized.isEmpty) return const {};
  return normalized
      .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
      .where((token) => token.isNotEmpty)
      .toSet();
}

/// The qualifier tokens the query names: each one that some query token
/// agrees with better than it agrees with any title token.
///
/// "Better than the title", not merely "at all", because the soft
/// agreement reaches three letters in: on `rice`, "Puerto Rican" agrees
/// with the query at 0.6 through `ric`, and read as named it would join
/// the scored text and cost its record — 0.867 against the plain record's
/// 1.0 — for a word the user never typed. The title already accounts for
/// `rice` at 1.0, so the qualifier stays out and the two records tie on
/// the title, as siblings should.
///
/// This is the rule the data source's cut and the resolver share, so the
/// qualifier a query names by inflection — `cheesy` for `cheese`, `yolks`
/// for `yolk` — is the same one at both.
Set<String> namedQualifiers(
  Set<String> titleTokens,
  Set<String> qualifierTokens,
  Set<String> queryTokens,
) => {
  for (final qualifier in qualifierTokens)
    if (queryTokens.any(
      (token) =>
          tokenSimilarity(token, qualifier) >
          _bestAgreement(token, titleTokens),
    ))
      qualifier,
};

double scoreText(String? text, Set<String> queryTokens, {String? qualifiers}) {
  final textTokens = tokenize(text);
  if (textTokens.isEmpty || queryTokens.isEmpty) return 0.0;
  if (qualifiers == null) return _softDice(textTokens, queryTokens);
  return _softDice({
    ...textTokens,
    ...namedQualifiers(textTokens, tokenize(qualifiers), queryTokens),
  }, queryTokens);
}
