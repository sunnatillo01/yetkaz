import 'package:food_delivery/core/entities/coordinates.dart';
import 'package:food_delivery/core/entities/paginated_list.dart';
import 'package:food_delivery/core/usecase/usecase.dart';
import 'package:food_delivery/features/home/domain/entities/home_entities.dart';
import 'package:food_delivery/features/home/domain/repositories/home_repository.dart';
import 'package:food_delivery/features/restaurant/domain/entities/restaurant.dart';
import 'package:injectable/injectable.dart';

/// Banners and categories, loaded in parallel and sorted by `order`.
@injectable
class GetHomeContent implements UseCase<HomeContent, NoParams> {
  const GetHomeContent(this._repository);
  final HomeRepository _repository;

  @override
  FutureEither<HomeContent> call(NoParams params) async {
    final (banners, categories) = await (
      _repository.getBanners(),
      _repository.getCategories(),
    ).wait;
    return banners.flatMap(
      (b) => categories.map(
        (c) => HomeContent(
          banners: [...b]..sort((x, y) => x.order.compareTo(y.order)),
          categories: [...c]..sort((x, y) => x.order.compareTo(y.order)),
        ),
      ),
    );
  }
}

class GetRestaurantsParams {
  const GetRestaurantsParams({required this.filter, this.cursor, this.limit = 10, this.near});

  final RestaurantFilter filter;
  final PageCursor? cursor;
  final int limit;
  final Coordinates? near;
}

@injectable
class GetRestaurants implements UseCase<PaginatedList<Restaurant>, GetRestaurantsParams> {
  const GetRestaurants(this._repository);
  final HomeRepository _repository;

  static const pageSize = 10;

  @override
  FutureEither<PaginatedList<Restaurant>> call(GetRestaurantsParams p) =>
      _repository.getRestaurants(filter: p.filter, cursor: p.cursor, limit: p.limit, near: p.near);
}

/// Sorts by distance to [from] (used for the "nearest" sort).
List<Restaurant> sortByDistance(List<Restaurant> items, Coordinates from) =>
    [...items]..sort((a, b) => a.location.distanceTo(from).compareTo(b.location.distanceTo(from)));

/// Used by the repository to emulate pagination over an in-memory list.
PaginatedList<T> pageOf<T>(List<T> all, {required int offset, required int limit}) {
  final end = (offset + limit).clamp(0, all.length);
  final items = offset >= all.length ? <T>[] : all.sublist(offset, end);
  final hasMore = end < all.length;
  return PaginatedList(
    items: items,
    hasMore: hasMore,
    nextCursor: hasMore ? PageCursor(['offset', end]) : null,
  );
}
