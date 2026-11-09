import 'package:food_delivery/core/error/exception_mapper.dart';
import 'package:food_delivery/core/usecase/usecase.dart';
import 'package:food_delivery/features/cart/data/datasources/cart_local_data_source.dart';
import 'package:food_delivery/features/cart/data/models/cart_model.dart';
import 'package:food_delivery/features/cart/domain/entities/cart.dart';
import 'package:food_delivery/features/cart/domain/repositories/cart_repository.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: CartRepository)
class CartRepositoryImpl implements CartRepository {
  CartRepositoryImpl(this._local);

  final CartLocalDataSource _local;

  @override
  FutureEither<Cart> load() async => guard(() async => _local.read().toEntity());

  @override
  FutureEither<Unit> save(Cart cart) => guard(() async {
    await _local.write(CartModel.fromEntity(cart));
    return unit;
  });

  @override
  FutureEither<Unit> clear() => guard(() async {
    await _local.clear();
    return unit;
  });
}
