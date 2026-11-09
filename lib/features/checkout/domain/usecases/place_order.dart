import 'package:food_delivery/core/error/failures.dart';
import 'package:food_delivery/core/usecase/usecase.dart';
import 'package:food_delivery/features/address/domain/entities/address.dart';
import 'package:food_delivery/features/cart/domain/entities/cart.dart';
import 'package:food_delivery/features/cart/domain/entities/cart_totals.dart';
import 'package:food_delivery/features/cart/domain/repositories/cart_repository.dart';
import 'package:food_delivery/features/order_tracking/domain/entities/order.dart';
import 'package:food_delivery/features/order_tracking/domain/repositories/order_repository.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

class PlaceOrderParams {
  const PlaceOrderParams({
    required this.cart,
    required this.address,
    required this.paymentMethod,
    required this.idempotencyKey,
    this.note = '',
  });

  final Cart cart;
  final Address? address;
  final PaymentMethod paymentMethod;
  final String idempotencyKey;
  final String note;
}

/// Validates the cart, sends the order to the server and clears the cart.
@injectable
class PlaceOrder implements UseCase<String, PlaceOrderParams> {
  const PlaceOrder(this._orders, this._cart);

  final OrderRepository _orders;
  final CartRepository _cart;

  static OrderRequest buildRequest(PlaceOrderParams p) => OrderRequest(
    idempotencyKey: p.idempotencyKey,
    restaurantId: p.cart.restaurant!.id,
    items: [
      for (final i in p.cart.items)
        OrderRequestItem(
          itemId: i.menuItemId,
          qty: i.quantity,
          options: i.options.map((o) => o.name).toList(),
        ),
    ],
    address: p.address!,
    paymentMethod: p.paymentMethod,
    note: p.note.trim(),
  );

  @override
  FutureEither<String> call(PlaceOrderParams p) async {
    if (p.cart.isEmpty || p.cart.restaurant == null) {
      return const Left(Failure.notFound());
    }
    if (!CartCalculator.calculate(p.cart).reachedMinOrder) {
      return const Left(Failure.business(BusinessErrorCode.belowMinOrder));
    }
    final result = await _orders.createOrder(buildRequest(p));
    return result.fold(Left.new, (orderId) async {
      await _cart.clear();
      return Right(orderId);
    });
  }
}
