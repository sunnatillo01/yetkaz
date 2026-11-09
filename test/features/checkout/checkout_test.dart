import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_delivery/core/error/failures.dart';
import 'package:food_delivery/features/cart/domain/entities/cart.dart';
import 'package:food_delivery/features/checkout/domain/usecases/place_order.dart';
import 'package:food_delivery/features/checkout/presentation/bloc/checkout_bloc.dart';
import 'package:food_delivery/features/order_tracking/domain/entities/order.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/fixtures.dart';
import '../../helpers/mocks.dart';

void main() {
  setUpAll(registerFallbacks);

  final cart = Cart.empty.add(tCartRestaurant, tCartItem(qty: 2, options: [tCheese]));

  group('PlaceOrder', () {
    late MockOrderRepository orders;
    late MockCartRepository carts;

    setUp(() {
      orders = MockOrderRepository();
      carts = MockCartRepository();
      when(() => carts.clear()).thenAnswer((_) async => const Right(unit));
    });

    PlaceOrderParams params(Cart c) => PlaceOrderParams(
      cart: c,
      address: tAddress,
      paymentMethod: PaymentMethod.card,
      idempotencyKey: 'key-1',
      note: '  ring twice ',
    );

    test('sends ids and quantities only (no prices) and clears the cart', () async {
      when(() => orders.createOrder(any())).thenAnswer((_) async => const Right('o1'));
      final result = await PlaceOrder(orders, carts)(params(cart));
      expect(result, const Right<Failure, String>('o1'));
      final request =
          verify(() => orders.createOrder(captureAny())).captured.single as OrderRequest;
      expect(request.idempotencyKey, 'key-1');
      expect(request.items.single.qty, 2);
      expect(request.items.single.options, ['Cheese']);
      expect(request.note, 'ring twice');
      verify(() => carts.clear()).called(1);
    });

    test('rejects a cart below the minimum without calling the server', () async {
      final small = Cart.empty.add(tCartRestaurant, tCartItem(price: 1000));
      final result = await PlaceOrder(orders, carts)(params(small));
      expect(
        result,
        const Left<Failure, String>(Failure.business(BusinessErrorCode.belowMinOrder)),
      );
      verifyNever(() => orders.createOrder(any()));
    });

    test('keeps the cart when the server fails', () async {
      when(() => orders.createOrder(any())).thenAnswer((_) async => const Left(Failure.network()));
      expect((await PlaceOrder(orders, carts)(params(cart))).isLeft(), isTrue);
      verifyNever(() => carts.clear());
    });

    test('empty cart is rejected', () async {
      expect((await PlaceOrder(orders, carts)(params(Cart.empty))).isLeft(), isTrue);
    });
  });

  group('CheckoutBloc', () {
    late MockPlaceOrder placeOrder;
    setUp(() => placeOrder = MockPlaceOrder());

    blocTest<CheckoutBloc, CheckoutState>(
      'places the order with the chosen payment method',
      build: () {
        when(() => placeOrder(any())).thenAnswer((_) async => const Right('o1'));
        return CheckoutBloc(placeOrder);
      },
      act: (b) => b
        ..add(const CheckoutEvent.paymentMethodChanged(PaymentMethod.card))
        ..add(CheckoutEvent.submitted(cart: cart, address: tAddress)),
      expect: () => [
        const CheckoutState(paymentMethod: PaymentMethod.card),
        const CheckoutState(paymentMethod: PaymentMethod.card, status: CheckoutStatus.loading()),
        const CheckoutState(
          paymentMethod: PaymentMethod.card,
          status: CheckoutStatus.success('o1'),
        ),
      ],
      verify: (b) {
        final p = verify(() => placeOrder(captureAny())).captured.single as PlaceOrderParams;
        expect(p.paymentMethod, PaymentMethod.card);
        expect(p.idempotencyKey, b.idempotencyKey);
      },
    );

    blocTest<CheckoutBloc, CheckoutState>(
      'double tap creates only one order',
      build: () {
        when(() => placeOrder(any())).thenAnswer((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return const Right('o1');
        });
        return CheckoutBloc(placeOrder);
      },
      act: (b) => b
        ..add(CheckoutEvent.submitted(cart: cart, address: tAddress))
        ..add(CheckoutEvent.submitted(cart: cart, address: tAddress)),
      wait: const Duration(milliseconds: 60),
      verify: (_) => verify(() => placeOrder(any())).called(1),
    );

    blocTest<CheckoutBloc, CheckoutState>(
      'asks for an address first',
      build: () => CheckoutBloc(placeOrder),
      act: (b) => b.add(CheckoutEvent.submitted(cart: cart, address: null)),
      expect: () => [const CheckoutState(addressMissing: true), const CheckoutState()],
      verify: (_) => verifyNever(() => placeOrder(any())),
    );

    blocTest<CheckoutBloc, CheckoutState>(
      'shows failure and allows retry with the same idempotency key',
      build: () {
        when(() => placeOrder(any())).thenAnswer((_) async => const Left(Failure.timeout()));
        return CheckoutBloc(placeOrder);
      },
      act: (b) async {
        b.add(CheckoutEvent.submitted(cart: cart, address: tAddress));
        await Future<void>.delayed(Duration.zero);
        b.add(CheckoutEvent.submitted(cart: cart, address: tAddress));
      },
      wait: const Duration(milliseconds: 20),
      verify: (b) {
        final keys = verify(() => placeOrder(captureAny())).captured
            .map((p) => (p as PlaceOrderParams).idempotencyKey)
            .toSet();
        expect(keys, {b.idempotencyKey});
        expect(b.state.status, const CheckoutStatus.failure(Failure.timeout()));
      },
    );
  });
}
