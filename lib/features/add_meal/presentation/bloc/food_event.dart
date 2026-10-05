part of 'food_bloc.dart';

abstract class FoodEvent extends Equatable {
  const FoodEvent();

  @override
  List<Object?> get props => [];
}

/// Immediate search — fired on submit (enter / search button) and tab change.
class LoadFoodEvent extends FoodEvent {
  final String searchString;

  const LoadFoodEvent({required this.searchString});

  @override
  List<Object?> get props => [searchString];
}

/// Fired on every keystroke. Diary Food runs immediately; recipes debounce.
class SearchFoodInputChangedEvent extends FoodEvent {
  final String searchString;

  const SearchFoodInputChangedEvent({required this.searchString});

  @override
  List<Object?> get props => [searchString];
}

class RefreshFoodEvent extends FoodEvent {
  const RefreshFoodEvent();

  @override
  List<Object?> get props => [];
}
