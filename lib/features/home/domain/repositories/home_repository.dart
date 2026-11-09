import 'package:food_delivery/core/entities/coordinates.dart';
import 'package:food_delivery/core/entities/paginated_list.dart';
import 'package:food_delivery/core/usecase/usecase.dart';
import 'package:food_delivery/features/home/domain/entities/home_entities.dart';
import 'package:food_delivery/features/restaurant/domain/entities/restaurant.dart';

abstract interface class HomeRepository {
  FutureEither<List<PromoBanner>> getBanners();

  FutureEither<List<Category>> getCategories();

  /// Paginated list. When offline, the first page falls back to the last
  /// cached page (`fromCache: true`).
  FutureEither<PaginatedList<Restaurant>> getRestaurants({
    required RestaurantFilter filter,
    PageCursor? cursor,
    int limit = 10,
    Coordinates? near,
  });
}
