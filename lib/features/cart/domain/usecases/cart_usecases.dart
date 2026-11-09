import 'package:food_delivery/core/usecase/usecase.dart';
import 'package:food_delivery/features/cart/domain/entities/cart.dart';
import 'package:food_delivery/features/cart/domain/repositories/cart_repository.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

sealed class AddToCartResult {
  const AddToCartResult();
}

class AddedToCart extends AddToCartResult {
  const AddedToCart(this.cart);
  final Cart cart;
}

/// The cart holds dishes of another restaurant — ask the user first.
class CartConflict extends AddToCartResult {
  const CartConflict();
}

class AddToCartParams {
  const AddToCartParams({
    required this.cart,
    required this.restaurant,
    required this.item,
    this.replaceExisting = false,
  });

  final Cart cart;
  final CartRestaurant restaurant;
  final CartItem item;

  /// `true` after the user confirmed "Clear the cart?".
  final bool replaceExisting;
}

@injectable
class AddToCart implements UseCase<AddToCartResult, AddToCartParams> {
  const AddToCart(this._repository);
  final CartRepository _repository;

  @override
  FutureEither<AddToCartResult> call(AddToCartParams p) async {
    if (p.cart.conflictsWith(p.restaurant.id) && !p.replaceExisting) {
      return const Right(CartConflict());
    }
    final base = p.replaceExisting ? Cart.empty : p.cart;
    final updated = base.add(p.restaurant, p.item);
    final saved = await _repository.save(updated);
    return saved.map((_) => AddedToCart(updated));
  }
}

@injectable
class SaveCart implements UseCase<Cart, Cart> {
  const SaveCart(this._repository);
  final CartRepository _repository;

  @override
  FutureEither<Cart> call(Cart cart) async => (await _repository.save(cart)).map((_) => cart);
}

@injectable
class LoadCart implements UseCase<Cart, NoParams> {
  const LoadCart(this._repository);
  final CartRepository _repository;

  @override
  FutureEither<Cart> call(NoParams params) => _repository.load();
}

@injectable
class ClearCart implements UseCase<Unit, NoParams> {
  const ClearCart(this._repository);
  final CartRepository _repository;

  @override
  FutureEither<Unit> call(NoParams params) => _repository.clear();
}
