import 'package:food_delivery/core/usecase/usecase.dart';
import 'package:food_delivery/features/restaurant/domain/entities/menu_item.dart';
import 'package:food_delivery/features/restaurant/domain/entities/restaurant.dart';

abstract interface class RestaurantRepository {
  FutureEither<Restaurant> getRestaurant(String id);

  /// Menu grouped into sections, in display order.
  FutureEither<List<MenuSection>> getMenu(String restaurantId);
}
