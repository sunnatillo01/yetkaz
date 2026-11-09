import 'package:food_delivery/core/usecase/usecase.dart';
import 'package:food_delivery/features/cart/domain/entities/cart.dart';
import 'package:food_delivery/features/cart/domain/repositories/cart_repository.dart';
import 'package:food_delivery/features/order_tracking/domain/entities/order.dart';
import 'package:food_delivery/features/profile/domain/repositories/profile_repository.dart';
import 'package:food_delivery/features/restaurant/domain/entities/restaurant.dart';
import 'package:food_delivery/features/restaurant/domain/repositories/restaurant_repository.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

@injectable
class ChangeAvatar implements UseCase<String?, AvatarSource> {
  const ChangeAvatar(this._repository);
  final ProfileRepository _repository;

  @override
  FutureEither<String?> call(AvatarSource source) => _repository.changeAvatar(source);
}

/// Builds a cart from an old order. Unit prices stored in the order already
/// include options, so the base price is restored by subtracting them.
Cart cartFromOrder(FoodOrder order, Restaurant restaurant) => Cart(
  restaurant: CartRestaurant(
    id: restaurant.id,
    name: restaurant.name,
    deliveryFee: restaurant.deliveryFee,
    minOrder: restaurant.minOrder,
  ),
  items: [
    for (final i in order.items)
      CartItem(
        menuItemId: i.itemId,
        name: i.name,
        imageUrl: i.imageUrl,
        basePrice: i.price - i.options.fold<int>(0, (s, o) => s + o.price),
        quantity: i.qty,
        options: i.options,
      ),
  ],
);

/// "Order again": replaces the cart with the dishes of [FoodOrder].
/// The current restaurant data (fees) is fetched; the server will
/// recalculate prices at checkout anyway.
@injectable
class Reorder implements UseCase<Cart, FoodOrder> {
  const Reorder(this._restaurants, this._cart);

  final RestaurantRepository _restaurants;
  final CartRepository _cart;

  @override
  FutureEither<Cart> call(FoodOrder order) async {
    final restaurant = await _restaurants.getRestaurant(order.restaurantId);
    return restaurant.fold(Left.new, (r) async {
      final cart = cartFromOrder(order, r);
      final saved = await _cart.save(cart);
      return saved.map((_) => cart);
    });
  }
}
