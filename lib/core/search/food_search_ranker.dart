import 'dart:isolate';
import 'package:sqlite3/sqlite3.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';

List<String> foodSearchWords(String text) => RegExp(
  r'[\p{L}\p{N}]+',
  unicode: true,
).allMatches(text.toLowerCase()).map((m) => m.group(0)!).toList();
String normalizeFoodSearchText(String text) => foodSearchWords(text).join(' ');
String? foodSearchMatch(String text) {
  final words = foodSearchWords(text);
  if (words.isEmpty) return null;
  return [
    for (var i = 0; i < words.length; i++)
      '"${words[i]}"${i == words.length - 1 ? '*' : ''}',
  ].join(' AND ');
}

String foodIdentity(MealEntity meal) =>
    '${meal.source.name}:${meal.code ?? meal.name ?? ''}';

/// Rescore all candidates in one temporary corpus instead of mixing scores from
/// different SQLite indices or Elasticsearch. Nothing personal is persisted.
Future<List<MealEntity>> rankFoodCandidates(
  String query,
  List<MealEntity> meals, {
  Set<String> remoteIdentities = const {},
  bool chronological = false,
}) async {
  final rows = [
    for (final meal in meals)
      [
        foodIdentity(meal),
        meal.scoringName ?? '',
        meal.brands ?? '',
        meal.scoringQualifiers ?? '',
      ],
  ];
  final indices = await _rankInBackground(
    query,
    rows,
    remoteIdentities,
    chronological,
  );
  return [for (final i in indices) meals[i]];
}

Future<List<int>> _rankInBackground(
  String query,
  List<List<String>> rows,
  Set<String> remote,
  bool chronological,
) => Isolate.run(() => _rank(query, rows, remote, chronological));
List<int> _rank(
  String query,
  List<List<String>> rows,
  Set<String> remote,
  bool chronological,
) {
  final match = foodSearchMatch(query);
  if (match == null) {
    return chronological ? List.generate(rows.length, (i) => i) : [];
  }
  final db = sqlite3.openInMemory();
  try {
    db.execute(
      '''CREATE VIRTUAL TABLE candidates USING fts5(identity UNINDEXED, name, brand, qualifiers,
      tokenize='unicode61 remove_diacritics 2')''',
    );
    final insert = db.prepare(
      'INSERT INTO candidates(rowid, identity, name, brand, qualifiers) VALUES(?, ?, ?, ?, ?)',
    );
    try {
      for (var i = 0; i < rows.length; i++) {
        insert.execute([i + 1, ...rows[i]]);
      }
    } finally {
      insert.close();
    }
    db.createFunction(
      functionName: 'normalize_name',
      argumentCount: const AllowedArgumentCount(1),
      function: (args) => normalizeFoodSearchText(args.single as String),
    );
    final order = chronological
        ? 'rowid'
        : 'CASE WHEN normalize_name(name) = ? THEN 0 ELSE 1 END, bm25(candidates, 0, 5, 2, 1), identity';
    final matching = db
        .select(
          'SELECT rowid FROM candidates WHERE candidates MATCH ? ORDER BY $order',
          chronological ? [match] : [match, normalizeFoodSearchText(query)],
        )
        .map((r) => (r['rowid'] as int) - 1)
        .toList();
    if (!chronological) {
      final found = matching.toSet();
      matching.addAll([
        for (var i = 0; i < rows.length; i++)
          if (!found.contains(i) && remote.contains(rows[i][0])) i,
      ]);
    }
    return matching;
  } finally {
    db.close();
  }
}
