import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_delivery/core/entities/paginated_list.dart';
import 'package:food_delivery/core/error/failures.dart';
import 'package:food_delivery/features/cart/domain/entities/cart.dart';
import 'package:food_delivery/features/order_tracking/domain/entities/order.dart';
import 'package:food_delivery/features/order_tracking/domain/usecases/order_usecases.dart';
import 'package:food_delivery/features/profile/domain/repositories/profile_repository.dart';
import 'package:food_delivery/features/profile/domain/usecases/profile_usecases.dart';
import 'package:food_delivery/features/profile/presentation/bloc/profile_cubits.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/fixtures.dart';
import '../../helpers/mocks.dart';

void main() {
  setUpAll(() {
    registerFallbacks();
    registerFallbackValue(AvatarSource.gallery);
  });

  group('Reorder', () {
    late MockRestaurantRepository restaurants;
    late MockCartRepository carts;

    setUp(() {
      restaurants = MockRestaurantRepository();
      carts = MockCartRepository();
      when(() => carts.save(any())).thenAnswer((_) async => const Right(unit));
    });

    test('cartFromOrder restores base prices and options', () {
      final cart = cartFromOrder(tOrder(), tRestaurant());
      final item = cart.items.single;
      expect(item.basePrice, 30000);
      expect(item.unitPrice, 35000);
      expect(item.quantity, 2);
      expect(cart.restaurant!.deliveryFee, 10000);
    });

    test('fills the cart with the old order', () async {
      when(() => restaurants.getRestaurant('r1')).thenAnswer((_) async => Right(tRestaurant()));
      final result = await Reorder(restaurants, carts)(tOrder());
      expect(result.getRight().toNullable()!.itemCount, 2);
      verify(() => carts.save(any())).called(1);
    });

    test('fails when the restaurant no longer exists', () async {
      when(() => restaurants.getRestaurant('r1'))
          .thenAnswer((_) async => const Left(Failure.notFound()));
      expect(
        await Reorder(restaurants, carts)(tOrder()),
        const Left<Failure, Cart>(Failure.notFound()),
      );
      verifyNever(() => carts.save(any()));
    });

    test('ChangeAvatar delegates to the repository', () async {
      final repo = MockProfileRepository();
      when(() => repo.changeAvatar(AvatarSource.camera))
          .thenAnswer((_) async => const Right('url'));
      expect(await ChangeAvatar(repo)(AvatarSource.camera), const Right<Failure, String?>('url'));
    });
  });

  group('ProfileCubit', () {
    late MockChangeAvatar changeAvatar;
    late MockLogout logout;
    late MockDeleteAccount deleteAccount;

    setUp(() {
      changeAvatar = MockChangeAvatar();
      logout = MockLogout();
      deleteAccount = MockDeleteAccount();
    });

    ProfileCubit build() => ProfileCubit(changeAvatar, logout, deleteAccount);

    blocTest<ProfileCubit, ProfileState>(
      'uploads the avatar',
      build: () {
        when(() => changeAvatar(any())).thenAnswer((_) async => const Right('url'));
        return build();
      },
      act: (c) => c.changeAvatar(AvatarSource.gallery),
      expect: () => [const ProfileState.loading(), const ProfileState.success()],
    );

    blocTest<ProfileCubit, ProfileState>(
      'logout success',
      build: () {
        when(() => logout(any())).thenAnswer((_) async => const Right(unit));
        return build();
      },
      act: (c) => c.logout(),
      expect: () => [const ProfileState.loading(), const ProfileState.success()],
    );

    blocTest<ProfileCubit, ProfileState>(
      'delete account failure',
      build: () {
        when(() => deleteAccount(any()))
            .thenAnswer((_) async => const Left(Failure.auth(AuthErrorCode.sessionExpired)));
        return build();
      },
      act: (c) => c.deleteAccount(),
      expect: () => [
        const ProfileState.loading(),
        const ProfileState.failure(Failure.auth(AuthErrorCode.sessionExpired)),
      ],
    );
  });

  group('OrdersHistoryBloc', () {
    late MockGetOrders getOrders;
    setUp(() => getOrders = MockGetOrders());

    final first = PaginatedList(
      items: [tOrder(id: 'a')],
      hasMore: true,
      nextCursor: const PageCursor(['c1']),
    );
    final second = PaginatedList(items: [tOrder(id: 'b')], hasMore: false);

    blocTest<OrdersHistoryBloc, OrdersHistoryState>(
      'loads completed orders',
      build: () {
        when(() => getOrders(any())).thenAnswer((_) async => Right(first));
        return OrdersHistoryBloc(getOrders, OrdersTab.completed);
      },
      act: (b) => b.add(const OrdersHistoryEvent.started()),
      expect: () => [
        const OrdersHistoryState.loading(),
        OrdersHistoryState.success(orders: first.items, hasMore: true, cursor: first.nextCursor),
      ],
      verify: (_) {
        final p = verify(() => getOrders(captureAny())).captured.single as GetOrdersParams;
        expect(p.active, isFalse);
      },
    );

    blocTest<OrdersHistoryBloc, OrdersHistoryState>(
      'paginates',
      build: () {
        when(() => getOrders(any())).thenAnswer((_) async => Right(second));
        return OrdersHistoryBloc(getOrders, OrdersTab.active);
      },
      seed: () =>
          OrdersHistoryState.success(orders: first.items, hasMore: true, cursor: first.nextCursor),
      act: (b) => b.add(const OrdersHistoryEvent.nextPageRequested()),
      skip: 1,
      expect: () => [
        OrdersHistoryState.success(orders: [...first.items, ...second.items], hasMore: false),
      ],
    );

    blocTest<OrdersHistoryBloc, OrdersHistoryState>(
      'failure',
      build: () {
        when(() => getOrders(any())).thenAnswer((_) async => const Left(Failure.network()));
        return OrdersHistoryBloc(getOrders, OrdersTab.active);
      },
      act: (b) => b.add(const OrdersHistoryEvent.started()),
      expect: () => [
        const OrdersHistoryState.loading(),
        const OrdersHistoryState.failure(Failure.network()),
      ],
    );
  });

  group('ReorderCubit', () {
    late MockReorder reorder;
    setUp(() => reorder = MockReorder());

    blocTest<ReorderCubit, ReorderState>(
      'success',
      build: () {
        when(() => reorder(any())).thenAnswer((_) async => const Right(Cart.empty));
        return ReorderCubit(reorder);
      },
      act: (c) => c.reorder(tOrder(status: OrderStatus.delivered)),
      expect: () => [ReorderState.loading(tOrder().id), const ReorderState.success(Cart.empty)],
    );

    blocTest<ReorderCubit, ReorderState>(
      'failure',
      build: () {
        when(() => reorder(any())).thenAnswer((_) async => const Left(Failure.notFound()));
        return ReorderCubit(reorder);
      },
      act: (c) => c.reorder(tOrder()),
      expect: () => [
        ReorderState.loading(tOrder().id),
        const ReorderState.failure(Failure.notFound()),
      ],
    );

    blocTest<ReorderCubit, ReorderState>(
      'ignores a second tap while loading',
      build: () {
        when(() => reorder(any())).thenAnswer((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return const Right(Cart.empty);
        });
        return ReorderCubit(reorder);
      },
      act: (c) {
        c
          ..reorder(tOrder())
          ..reorder(tOrder());
      },
      wait: const Duration(milliseconds: 30),
      verify: (_) => verify(() => reorder(any())).called(1),
    );
  });
}
