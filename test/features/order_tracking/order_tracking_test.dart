import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_delivery/core/entities/coordinates.dart';
import 'package:food_delivery/core/error/failures.dart';
import 'package:food_delivery/features/order_tracking/data/models/order_model.dart';
import 'package:food_delivery/features/order_tracking/domain/entities/order.dart';
import 'package:food_delivery/features/order_tracking/domain/usecases/order_usecases.dart';
import 'package:food_delivery/features/order_tracking/presentation/bloc/order_tracking_bloc.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/fixtures.dart';
import '../../helpers/mocks.dart';

void main() {
  setUpAll(registerFallbacks);

  group('Order entity', () {
    test('only a created order can be cancelled', () {
      expect(tOrder().canCancel, isTrue);
      for (final s in OrderStatus.values.where((s) => s != OrderStatus.created)) {
        expect(tOrder(status: s).canCancel, isFalse, reason: s.name);
      }
    });

    test('final statuses', () {
      expect(tOrder(status: OrderStatus.delivered).isActive, isFalse);
      expect(tOrder(status: OrderStatus.cancelled).isActive, isFalse);
      expect(tOrder(status: OrderStatus.onTheWay).isActive, isTrue);
    });

    test('status parsing uses Firestore values', () {
      expect(OrderStatus.parse('on_the_way'), OrderStatus.onTheWay);
      expect(OrderStatus.parse('unknown'), OrderStatus.created);
      expect(tOrder().shortId, '123456');
      expect(tOrder().itemCount, 2);
    });

    test('model maps Firestore JSON', () {
      final model = OrderModel.fromJson({
        'id': 'o1',
        'userId': 'u1',
        'restaurantId': 'r1',
        'restaurantName': 'R',
        'restaurantLocation': {'lat': 41.3, 'lng': 69.2},
        'address': {'lat': 41.4, 'lng': 69.3, 'text': 'Home', 'title': 'home'},
        'items': [
          {'itemId': 'm1', 'name': 'Burger', 'price': 35000, 'qty': 2},
        ],
        'subtotal': 70000,
        'deliveryFee': 10000,
        'serviceFee': 3500,
        'total': 83500,
        'status': 'on_the_way',
        'paymentMethod': 'card',
        'courier': {'lat': 41.35, 'lng': 69.25, 'name': 'Jasur', 'phone': '+998'},
        'route': [
          {'lat': 41.3, 'lng': 69.2},
        ],
        'etaMinutes': 5,
        'createdAt': '2026-11-09T12:00:00.000',
      });
      final order = model.toEntity();
      expect(order.status, OrderStatus.onTheWay);
      expect(order.paymentMethod, PaymentMethod.card);
      expect(order.courier!.location, const Coordinates(lat: 41.35, lng: 69.25));
      expect(order.items.single.lineTotal, 70000);
    });
  });

  group('CancelOrder', () {
    late MockOrderRepository repo;
    setUp(() => repo = MockOrderRepository());

    test('cancels a created order', () async {
      when(() => repo.cancelOrder(any())).thenAnswer((_) async => const Right(unit));
      expect(await CancelOrder(repo)(tOrder()), const Right<Failure, Unit>(unit));
    });

    test('refuses after the restaurant accepted', () async {
      final result = await CancelOrder(repo)(tOrder(status: OrderStatus.cooking));
      expect(result, const Left<Failure, Unit>(Failure.business(BusinessErrorCode.notCancellable)));
      verifyNever(() => repo.cancelOrder(any()));
    });

    test('GetOrders forwards pagination params', () async {
      when(() => repo.getOrders(active: false))
          .thenAnswer((_) async => const Left(Failure.network()));
      await GetOrders(repo)(const GetOrdersParams(active: false));
      verify(() => repo.getOrders(active: false)).called(1);
    });
  });

  group('OrderTrackingBloc', () {
    late MockWatchOrder watch;
    late MockCancelOrder cancel;
    late StreamController<Either<Failure, FoodOrder>> updates;
    var listens = 0;

    setUp(() {
      watch = MockWatchOrder();
      cancel = MockCancelOrder();
      listens = 0;
      updates = StreamController.broadcast(onListen: () => listens++);
      when(() => watch(any())).thenAnswer((_) => updates.stream);
    });

    OrderTrackingBloc build() => OrderTrackingBloc(watch, cancel);

    blocTest<OrderTrackingBloc, OrderTrackingState>(
      'streams status changes',
      build: build,
      act: (b) async {
        b.add(const OrderTrackingEvent.started('o1'));
        await Future<void>.delayed(Duration.zero);
        updates
          ..add(Right(tOrder()))
          ..add(Right(tOrder(status: OrderStatus.cooking)));
      },
      expect: () => [
        const OrderTrackingState.loading(),
        OrderTrackingState.success(order: tOrder()),
        OrderTrackingState.success(order: tOrder(status: OrderStatus.cooking)),
      ],
    );

    blocTest<OrderTrackingBloc, OrderTrackingState>(
      'stops listening in background and reconnects on resume',
      build: build,
      act: (b) async {
        b.add(const OrderTrackingEvent.started('o1'));
        await Future<void>.delayed(Duration.zero);
        expect(b.isListening, isTrue);
        b.add(const OrderTrackingEvent.paused());
        await Future<void>.delayed(Duration.zero);
        expect(b.isListening, isFalse);
        b.add(const OrderTrackingEvent.resumed());
        await Future<void>.delayed(Duration.zero);
        expect(b.isListening, isTrue);
      },
      verify: (b) {
        verify(() => watch('o1')).called(2);
      },
    );

    blocTest<OrderTrackingBloc, OrderTrackingState>(
      'initial stream error shows the failure screen',
      build: build,
      act: (b) async {
        b.add(const OrderTrackingEvent.started('o1'));
        await Future<void>.delayed(Duration.zero);
        updates.add(const Left(Failure.notFound()));
      },
      expect: () => [
        const OrderTrackingState.loading(),
        const OrderTrackingState.failure(Failure.notFound()),
      ],
    );

    blocTest<OrderTrackingBloc, OrderTrackingState>(
      'cancel request shows progress and the error if refused',
      build: () {
        when(
          () => cancel(any()),
        ).thenAnswer((_) async => const Left(Failure.business(BusinessErrorCode.notCancellable)));
        return build();
      },
      seed: () => OrderTrackingState.success(order: tOrder()),
      act: (b) => b.add(const OrderTrackingEvent.cancelRequested()),
      expect: () => [
        OrderTrackingState.success(order: tOrder(), isCancelling: true),
        OrderTrackingState.success(
          order: tOrder(),
          actionFailure: const Failure.business(BusinessErrorCode.notCancellable),
        ),
      ],
    );

    blocTest<OrderTrackingBloc, OrderTrackingState>(
      'delivered order closes the subscription',
      build: build,
      act: (b) async {
        b.add(const OrderTrackingEvent.started('o1'));
        await Future<void>.delayed(Duration.zero);
        updates.add(Right(tOrder(status: OrderStatus.delivered)));
        await Future<void>.delayed(Duration.zero);
        expect(b.isListening, isFalse);
      },
    );
  });
}
