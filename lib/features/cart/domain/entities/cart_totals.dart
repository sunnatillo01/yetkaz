import 'dart:math' as math;

import 'package:food_delivery/features/cart/domain/entities/cart.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'cart_totals.freezed.dart';

/// All money values are integer so'm — never `double`.
@freezed
abstract class CartTotals with _$CartTotals {
  const factory CartTotals({
    required int subtotal,
    required int deliveryFee,
    required int serviceFee,
    required int total,
    required int minOrderRemaining,
  }) = _CartTotals;
  const CartTotals._();

  static const zero = CartTotals(
    subtotal: 0,
    deliveryFee: 0,
    serviceFee: 0,
    total: 0,
    minOrderRemaining: 0,
  );

  bool get reachedMinOrder => minOrderRemaining == 0;
}

/// Pricing rules. The Cloud Function `createOrder` mirrors them exactly and
/// recalculates on the server — the client total is never trusted.
abstract final class CartCalculator {
  /// Service fee: 5% of subtotal rounded half-up to the nearest 100 so'm.
  static int serviceFee(int subtotal) {
    if (subtotal <= 0) return 0;
    return ((subtotal * 5 + 5000) ~/ 10000) * 100;
  }

  static CartTotals calculate(Cart cart) {
    if (cart.isEmpty || cart.restaurant == null) return CartTotals.zero;
    final subtotal = cart.items.fold<int>(0, (s, i) => s + i.lineTotal);
    final delivery = cart.restaurant!.deliveryFee;
    final service = serviceFee(subtotal);
    return CartTotals(
      subtotal: subtotal,
      deliveryFee: delivery,
      serviceFee: service,
      total: subtotal + delivery + service,
      minOrderRemaining: math.max(0, cart.restaurant!.minOrder - subtotal),
    );
  }
}
