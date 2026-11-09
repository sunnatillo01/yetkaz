import 'package:food_delivery/core/error/exception_mapper.dart';
import 'package:food_delivery/core/usecase/usecase.dart';
import 'package:food_delivery/features/restaurant/domain/entities/restaurant.dart';
import 'package:food_delivery/features/search/data/datasources/search_data_sources.dart';
import 'package:food_delivery/features/search/domain/repositories/search_repository.dart';
import 'package:food_delivery/features/search/domain/usecases/search_usecases.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: SearchRepository)
class SearchRepositoryImpl implements SearchRepository {
  SearchRepositoryImpl(this._remote, this._history);

  final SearchRemoteDataSource _remote;
  final SearchHistoryDataSource _history;

  @override
  FutureEither<List<Restaurant>> search(String query) =>
      guard(() async => (await _remote.search(query)).map((m) => m.toEntity()).toList());

  @override
  List<String> history() => _history.read();

  @override
  Future<List<String>> addToHistory(String query) async {
    final updated = pushHistory(_history.read(), query);
    await _history.write(updated);
    return updated;
  }

  @override
  Future<void> clearHistory() => _history.clear();
}
