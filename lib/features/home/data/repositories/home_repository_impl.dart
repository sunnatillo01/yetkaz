import 'package:food_delivery/core/entities/coordinates.dart';
import 'package:food_delivery/core/entities/paginated_list.dart';
import 'package:food_delivery/core/error/exception_mapper.dart';
import 'package:food_delivery/core/error/exceptions.dart';
import 'package:food_delivery/core/error/failures.dart';
import 'package:food_delivery/core/network/network_info.dart';
import 'package:food_delivery/core/usecase/usecase.dart';
import 'package:food_delivery/features/home/data/datasources/home_data_sources.dart';
import 'package:food_delivery/features/home/domain/entities/home_entities.dart';
import 'package:food_delivery/features/home/domain/repositories/home_repository.dart';
import 'package:food_delivery/features/home/domain/usecases/home_usecases.dart';
import 'package:food_delivery/features/restaurant/domain/entities/restaurant.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: HomeRepository)
class HomeRepositoryImpl implements HomeRepository {
  HomeRepositoryImpl(this._remote, this._local, this._network);

  final HomeRemoteDataSource _remote;
  final HomeLocalDataSource _local;
  final NetworkInfo _network;

  /// How many restaurants are sorted by distance for "nearest".
  static const nearestPoolSize = 50;

  List<Restaurant>? _nearestPool;

  @override
  FutureEither<List<PromoBanner>> getBanners() =>
      guard(() async => (await _remote.getBanners()).map((b) => b.toEntity()).toList());

  @override
  FutureEither<List<Category>> getCategories() =>
      guard(() async => (await _remote.getCategories()).map((c) => c.toEntity()).toList());

  @override
  FutureEither<PaginatedList<Restaurant>> getRestaurants({
    required RestaurantFilter filter,
    PageCursor? cursor,
    int limit = 10,
    Coordinates? near,
  }) async {
    final isFirstPage = cursor == null;
    if (isFirstPage && !await _network.isConnected) {
      return _fromCache(filter);
    }
    if (filter.sort == RestaurantSort.nearest && near != null) {
      return _nearest(filter, cursor, limit, near);
    }
    final result = await guard(() async {
      final models = await _remote.getRestaurants(
        filter: filter,
        limit: limit,
        afterId: cursor?.values.last as String?,
      );
      if (isFirstPage && filter.isDefault) await _local.cacheRestaurants(models);
      return PaginatedList(
        items: models.map((m) => m.toEntity()).toList(),
        hasMore: models.length == limit,
        nextCursor: models.isEmpty ? null : PageCursor(['doc', models.last.id]),
      );
    });
    // Network dropped mid-request: show the cached page instead of an error.
    if (isFirstPage && result.isLeft()) {
      final failure = result.getLeft().toNullable();
      if (failure is NetworkFailure || failure is TimeoutFailure) {
        final cached = await _fromCache(filter);
        if (cached.isRight()) return cached;
      }
    }
    return result;
  }

  /// Firestore cannot order by distance: take the most popular
  /// [nearestPoolSize] restaurants, sort them by distance and page in memory.
  FutureEither<PaginatedList<Restaurant>> _nearest(
    RestaurantFilter filter,
    PageCursor? cursor,
    int limit,
    Coordinates near,
  ) => guard(() async {
    if (cursor == null || _nearestPool == null) {
      final models = await _remote.getRestaurants(
        filter: filter.copyWith(sort: RestaurantSort.popular),
        limit: nearestPoolSize,
      );
      _nearestPool = sortByDistance(models.map((m) => m.toEntity()).toList(), near);
    }
    final offset = cursor == null ? 0 : cursor.values.last! as int;
    return pageOf(_nearestPool!, offset: offset, limit: limit);
  });

  FutureEither<PaginatedList<Restaurant>> _fromCache(RestaurantFilter filter) => guard(() async {
    final cached = _local.cachedRestaurants();
    if (cached.isEmpty) throw const NetworkException();
    return PaginatedList(
      items: cached.map((m) => m.toEntity()).where(filter.matches).toList(),
      hasMore: false,
      fromCache: true,
    );
  }).then((r) => r.mapLeft((f) => f is CacheFailure ? const Failure.network() : f));
}
