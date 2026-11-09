import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:food_delivery/core/error/failures.dart';
import 'package:food_delivery/core/utils/debouncer.dart';
import 'package:food_delivery/features/restaurant/domain/entities/restaurant.dart';
import 'package:food_delivery/features/search/domain/usecases/search_usecases.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'search_bloc.freezed.dart';

@freezed
sealed class SearchEvent with _$SearchEvent {
  const factory SearchEvent.started() = SearchStarted;

  /// Typing — debounced by [SearchBloc.debounce].
  const factory SearchEvent.queryChanged(String query) = SearchQueryChanged;

  /// Tapping a history item — searches immediately.
  const factory SearchEvent.submitted(String query) = SearchSubmitted;
  const factory SearchEvent.historyCleared() = SearchHistoryCleared;
}

@freezed
sealed class SearchState with _$SearchState {
  const factory SearchState.initial(List<String> history) = SearchInitial;
  const factory SearchState.loading(String query) = SearchLoading;
  const factory SearchState.success({required String query, required List<Restaurant> results}) =
      SearchSuccess;
  const factory SearchState.failure({required String query, required Failure failure}) =
      SearchFailure;
}

@injectable
class SearchBloc extends Bloc<SearchEvent, SearchState> {
  SearchBloc(this._search, this._getHistory, this._clearHistory)
    : super(const SearchState.initial([])) {
    on<SearchStarted>((_, emit) => emit(SearchState.initial(_getHistory())));
    on<SearchQueryChanged>(
      (e, emit) => _run(e.query, emit),
      transformer: debounceRestartable(debounce),
    );
    on<SearchSubmitted>((e, emit) => _run(e.query, emit));
    on<SearchHistoryCleared>((_, emit) async {
      await _clearHistory();
      emit(const SearchState.initial([]));
    });
  }

  static const debounce = Duration(milliseconds: 400);

  final SearchRestaurants _search;
  final GetSearchHistory _getHistory;
  final ClearSearchHistory _clearHistory;

  Future<void> _run(String query, Emitter<SearchState> emit) async {
    if (normalizeQuery(query).length < SearchRestaurants.minLength) {
      emit(SearchState.initial(_getHistory()));
      return;
    }
    emit(SearchState.loading(query));
    final result = await _search(query);
    emit(
      result.fold(
        (f) => SearchState.failure(query: query, failure: f),
        (r) => SearchState.success(query: query, results: r),
      ),
    );
  }
}
