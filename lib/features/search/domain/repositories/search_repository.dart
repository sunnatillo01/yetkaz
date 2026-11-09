import 'package:food_delivery/core/usecase/usecase.dart';
import 'package:food_delivery/features/restaurant/domain/entities/restaurant.dart';

abstract interface class SearchRepository {
  /// Matches restaurant names and dish names.
  FutureEither<List<Restaurant>> search(String query);

  /// Most recent first, at most [maxHistory] entries.
  List<String> history();

  Future<List<String>> addToHistory(String query);

  Future<void> clearHistory();

  static const maxHistory = 5;
}
