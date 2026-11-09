import 'package:food_delivery/core/usecase/usecase.dart';
import 'package:food_delivery/features/restaurant/domain/entities/restaurant.dart';
import 'package:food_delivery/features/search/domain/repositories/search_repository.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

/// Normalises the query: trimmed, lower-case, single spaces.
String normalizeQuery(String query) => query.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

/// Adds [query] to the front of [history], de-duplicated, limited to [max].
List<String> pushHistory(List<String> history, String query, {int max = 5}) =>
    [query, ...history.where((h) => h.toLowerCase() != query.toLowerCase())].take(max).toList();

@injectable
class SearchRestaurants implements UseCase<List<Restaurant>, String> {
  const SearchRestaurants(this._repository);
  final SearchRepository _repository;

  static const minLength = 2;

  @override
  FutureEither<List<Restaurant>> call(String query) async {
    final q = normalizeQuery(query);
    if (q.length < minLength) return const Right([]);
    final result = await _repository.search(q);
    if (result.isRight()) await _repository.addToHistory(query.trim());
    return result;
  }
}

@injectable
class GetSearchHistory {
  const GetSearchHistory(this._repository);
  final SearchRepository _repository;

  List<String> call() => _repository.history();
}

@injectable
class ClearSearchHistory {
  const ClearSearchHistory(this._repository);
  final SearchRepository _repository;

  Future<void> call() => _repository.clearHistory();
}
