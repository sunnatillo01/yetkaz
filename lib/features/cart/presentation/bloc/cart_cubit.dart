import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:food_delivery/core/error/failures.dart';
import 'package:food_delivery/core/usecase/usecase.dart';
import 'package:food_delivery/features/cart/domain/entities/cart.dart';
import 'package:food_delivery/features/cart/domain/entities/cart_totals.dart';
import 'package:food_delivery/features/cart/domain/usecases/cart_usecases.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'cart_cubit.freezed.dart';

@freezed
sealed class CartState with _$CartState {
  const factory CartState.initial() = CartInitial;
  const factory CartState.loading() = CartLoading;
  const factory CartState.success({required Cart cart, required CartTotals totals}) = CartSuccess;
  const factory CartState.failure(Failure failure) = CartFailure;
}

extension CartStateX on CartState {
  Cart get cart => switch (this) {
    CartSuccess(:final cart) => cart,
    _ => Cart.empty,
  };
}

/// App-wide cart. Persisted in Hive through the repository.
@lazySingleton
class CartCubit extends Cubit<CartState> {
  CartCubit(this._loadCart, this._addToCart, this._saveCart, this._clearCart)
    : super(const CartState.initial());

  final LoadCart _loadCart;
  final AddToCart _addToCart;
  final SaveCart _saveCart;
  final ClearCart _clearCart;

  Future<void> load() async {
    emit(const CartState.loading());
    final result = await _loadCart(const NoParams());
    result.fold((f) => emit(CartState.failure(f)), _emitCart);
  }

  void _emitCart(Cart cart) =>
      emit(CartState.success(cart: cart, totals: CartCalculator.calculate(cart)));

  /// Returns [CartConflict] when the cart has dishes of another restaurant;
  /// the UI then asks and calls again with `replaceExisting: true`.
  Future<AddToCartResult?> add(
    CartRestaurant restaurant,
    CartItem item, {
    bool replaceExisting = false,
  }) async {
    final result = await _addToCart(
      AddToCartParams(
        cart: state.cart,
        restaurant: restaurant,
        item: item,
        replaceExisting: replaceExisting,
      ),
    );
    return result.fold(
      (f) {
        emit(CartState.failure(f));
        return null;
      },
      (r) {
        if (r is AddedToCart) _emitCart(r.cart);
        return r;
      },
    );
  }

  Future<void> changeQuantity(String key, int quantity) =>
      _persist(state.cart.updateQuantity(key, quantity));

  Future<void> remove(String key) => _persist(state.cart.remove(key));

  /// Replaces the whole cart (used by "Order again").
  Future<void> replace(Cart cart) => _persist(cart);

  Future<void> clear() async {
    await _clearCart(const NoParams());
    _emitCart(Cart.empty);
  }

  Future<void> _persist(Cart cart) async {
    _emitCart(cart); // optimistic: UI updates immediately
    final result = await _saveCart(cart);
    result.fold((f) => emit(CartState.failure(f)), (_) {});
  }
}
