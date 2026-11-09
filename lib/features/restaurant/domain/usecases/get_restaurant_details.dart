import 'package:food_delivery/core/usecase/usecase.dart';
import 'package:food_delivery/features/restaurant/domain/entities/menu_item.dart';
import 'package:food_delivery/features/restaurant/domain/repositories/restaurant_repository.dart';
import 'package:injectable/injectable.dart';

/// Loads the restaurant and its menu in parallel.
@injectable
class GetRestaurantDetails implements UseCase<RestaurantDetails, String> {
  const GetRestaurantDetails(this._repository);
  final RestaurantRepository _repository;

  @override
  FutureEither<RestaurantDetails> call(String restaurantId) async {
    final (restaurant, menu) = await (
      _repository.getRestaurant(restaurantId),
      _repository.getMenu(restaurantId),
    ).wait;
    return restaurant.flatMap(
      (r) => menu.map((sections) => RestaurantDetails(restaurant: r, sections: sections)),
    );
  }
}

/// Price of a dish with selected extras multiplied by quantity.
int dishTotal({
  required int basePrice,
  required Iterable<int> optionPrices,
  required int quantity,
}) => (basePrice + optionPrices.fold<int>(0, (a, b) => a + b)) * quantity;
