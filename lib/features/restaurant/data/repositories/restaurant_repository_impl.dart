import 'package:food_delivery/core/error/exception_mapper.dart';
import 'package:food_delivery/core/usecase/usecase.dart';
import 'package:food_delivery/features/restaurant/data/datasources/restaurant_remote_data_source.dart';
import 'package:food_delivery/features/restaurant/data/models/restaurant_model.dart';
import 'package:food_delivery/features/restaurant/domain/entities/menu_item.dart';
import 'package:food_delivery/features/restaurant/domain/entities/restaurant.dart';
import 'package:food_delivery/features/restaurant/domain/repositories/restaurant_repository.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: RestaurantRepository)
class RestaurantRepositoryImpl implements RestaurantRepository {
  RestaurantRepositoryImpl(this._remote);

  final RestaurantRemoteDataSource _remote;

  @override
  FutureEither<Restaurant> getRestaurant(String id) =>
      guard(() async => (await _remote.getRestaurant(id)).toEntity());

  @override
  FutureEither<List<MenuSection>> getMenu(String restaurantId) =>
      guard(() async => groupMenu(await _remote.getMenu(restaurantId)));
}
