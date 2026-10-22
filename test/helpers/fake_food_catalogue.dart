import 'package:opennutritracker/features/add_meal/data/food_catalogue.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';

CatalogueSource catalogueSource(
  String id,
  String name, {
  bool termsRequired = false,
}) => CatalogueSource(
  id: id,
  name: name,
  releases: const {'main': '2024'},
  attribution: '$name publisher',
  website: 'https://example.org/$id',
  termsUrl: 'https://example.org/$id/terms',
  termsRequired: termsRequired,
);

class FakeFoodCatalogue implements FoodCatalogue {
  FakeFoodCatalogue(this.sourceList);
  final List<CatalogueSource> sourceList;
  Future<List<CatalogueSource>> Function()? loadSources;
  Future<List<MealEntity>> Function(String, Set<String>?)? onSearch;
  final selections = <Set<String>?>[];

  @override
  Future<List<CatalogueSource>> sources() async =>
      loadSources == null ? sourceList : await loadSources!();

  @override
  Future<List<MealEntity>> search(
    String query, {
    Set<String>? sourceIds,
  }) async {
    selections.add(sourceIds);
    return await onSearch?.call(query, sourceIds) ?? [];
  }

  @override
  Future<MealEntity?> getById(String catalogueId) async => null;
}
