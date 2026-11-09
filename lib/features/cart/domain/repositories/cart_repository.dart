import 'package:food_delivery/core/usecase/usecase.dart';
import 'package:food_delivery/features/cart/domain/entities/cart.dart';
import 'package:fpdart/fpdart.dart';

abstract interface class CartRepository {
  FutureEither<Cart> load();
  FutureEither<Unit> save(Cart cart);
  FutureEither<Unit> clear();
}
