import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:stream_transform/stream_transform.dart';

/// Search-as-you-type timing for Products and the recipe Food picker.
const searchDebounceDuration = Duration(milliseconds: 500);

/// Minimum trimmed query length for Products and the recipe Food picker.
/// The diary catalogue searches single-character input without this limit.
const minQueryLength = 2;

/// Debounce keystrokes, then run the latest one as a restartable handler so an
/// in-flight search is cancelled the moment a newer query arrives. Keeps the
/// remote source to roughly one request per typing pause.
EventTransformer<E> debounceRestartable<E>(Duration duration) {
  return (events, mapper) =>
      restartable<E>().call(events.debounce(duration), mapper);
}
