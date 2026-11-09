import 'dart:convert';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_delivery/core/error/failures.dart';
import 'package:food_delivery/features/cart/data/datasources/cart_local_data_source.dart';
import 'package:food_delivery/features/cart/data/models/cart_model.dart';
import 'package:food_delivery/features/cart/data/repositories/cart_repository_impl.dart';
import 'package:food_delivery/features/cart/domain/entities/cart.dart';
import 'package:food_delivery/features/cart/domain/entities/cart_totals.dart';
import 'package:food_delivery/features/cart/domain/usecases/cart_usecases.dart';
import 'package:food_delivery/features/cart/presentation/bloc/cart_cubit.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/fixtures.dart';
import '../../helpers/mocks.dart';

class _MockBox extends Mock implements Box<String>;

void main() {
  setUpAll(registerFallbacks);

  group('Cart entity', () {
    test('merges the same dish with the same options', () {
      final cart = Cart.empty
          .add(tCartRestaurant, tCartItem(options: [tCheese]))
          .add(tCartRestaurant, tCartItem(qty: 2, options: [tCheese]));
      expect(cart.items, hasLength(1));
      expect(cart.items.single.quantity, 3);
      expect(cart.itemCount, 3);
    });

    test('keeps different options as separate lines', () {
      final cart = Cart.empty
          .add(tCartRestaurant, tCartItem())
          .add(tCartRestaurant, tCartItem(options: [tCheese]));
      expect(cart.items, hasLength(2));
      expect(cart.quantityOf('m1'), 2);
    });

    test('unit price includes options', () {
      final item = tCartItem(qty: 2, options: [tCheese]);
      expect(item.unitPrice, 35000);
      expect(item.lineTotal, 70000);
    });

    test('detects another restaurant', () {
      final cart = Cart.empty.add(tCartRestaurant, tCartItem());
      expect(cart.conflictsWith('r1'), isFalse);
      expect(cart.conflictsWith('r2'), isTrue);
      expect(Cart.empty.conflictsWith('r2'), isFalse);
    });

    test('quantity 0 removes the line; removing the last line empties the cart', () {
      final item = tCartItem();
      final cart = Cart.empty.add(tCartRestaurant, item);
      expect(cart.updateQuantity(item.key, 5).items.single.quantity, 5);
      expect(cart.updateQuantity(item.key, 0), Cart.empty);
      expect(cart.remove(item.key).restaurant, isNull);
    });
  });

  group('CartCalculator', () {
    test("service fee is 5% rounded half-up to 100 so'm", () {
      expect(CartCalculator.serviceFee(0), 0);
      expect(CartCalculator.serviceFee(45000), 2300);
      expect(CartCalculator.serviceFee(100000), 5000);
      expect(CartCalculator.serviceFee(1000), 100);
    });

    test('total = items + delivery + service, all int', () {
      final cart = Cart.empty.add(tCartRestaurant, tCartItem(qty: 2, options: [tCheese]));
      final totals = CartCalculator.calculate(cart);
      expect(totals.subtotal, 70000);
      expect(totals.deliveryFee, 10000);
      expect(totals.serviceFee, 3500);
      expect(totals.total, 83500);
      expect(totals.reachedMinOrder, isTrue);
    });

    test('shows how much is left to the minimum order', () {
      final cart = Cart.empty.add(tCartRestaurant, tCartItem(price: 20000));
      expect(CartCalculator.calculate(cart).minOrderRemaining, 30000);
      expect(CartCalculator.calculate(cart).reachedMinOrder, isFalse);
    });

    test('empty cart is zero', () {
      expect(CartCalculator.calculate(Cart.empty), CartTotals.zero);
    });
  });

  group('AddToCart', () {
    late MockCartRepository repo;
    setUp(() {
      repo = MockCartRepository();
      when(() => repo.save(any())).thenAnswer((_) async => const Right(unit));
    });

    test('returns conflict for another restaurant without saving', () async {
      final cart = Cart.empty.add(tCartRestaurant, tCartItem());
      final other = tCartRestaurant.copyWith(id: 'r2');
      final result = await AddToCart(repo)(
        AddToCartParams(cart: cart, restaurant: other, item: tCartItem()),
      );
      expect(result.getRight().toNullable(), isA<CartConflict>());
      verifyNever(() => repo.save(any()));
    });

    test('replaces the cart after confirmation', () async {
      final cart = Cart.empty.add(tCartRestaurant, tCartItem());
      final other = tCartRestaurant.copyWith(id: 'r2');
      final result = await AddToCart(repo)(
        AddToCartParams(
          cart: cart,
          restaurant: other,
          item: tCartItem(id: 'x'),
          replaceExisting: true,
        ),
      );
      final added = result.getRight().toNullable()! as AddedToCart;
      expect(added.cart.restaurant!.id, 'r2');
      expect(added.cart.items.single.menuItemId, 'x');
    });
  });

  group('CartRepositoryImpl (Hive)', () {
    late _MockBox box;
    late CartRepositoryImpl repo;

    setUp(() {
      box = _MockBox();
      repo = CartRepositoryImpl(CartLocalDataSource(box));
    });

    test('round-trips the cart through JSON', () async {
      final cart = Cart.empty.add(tCartRestaurant, tCartItem(options: [tCheese]));
      String? stored;
      when(() => box.put(any<dynamic>(), any<String>())).thenAnswer((inv) async {
        stored = inv.positionalArguments[1] as String;
      });
      await repo.save(cart);
      when(() => box.get(any<dynamic>())).thenAnswer((_) => stored);
      expect((await repo.load()).getRight().toNullable(), cart);
    });

    test('empty storage gives an empty cart', () async {
      when(() => box.get(any<dynamic>())).thenReturn(null);
      expect((await repo.load()).getRight().toNullable(), Cart.empty);
    });

    test('corrupted data is a CacheFailure', () async {
      when(() => box.get(any<dynamic>())).thenReturn('{not json');
      expect(await repo.load(), const Left<Failure, Cart>(Failure.cache()));
    });

    test('model keeps restaurant fees', () {
      final json = jsonEncode(
        CartModel.fromEntity(Cart.empty.add(tCartRestaurant, tCartItem())).toJson(),
      );
      final back = CartModel.fromJson(jsonDecode(json) as Map<String, dynamic>).toEntity();
      expect(back.restaurant, tCartRestaurant);
    });
  });

  group('CartCubit', () {
    late MockLoadCart load;
    late MockAddToCart add;
    late MockSaveCart save;
    late MockClearCart clear;

    setUp(() {
      load = MockLoadCart();
      add = MockAddToCart();
      save = MockSaveCart();
      clear = MockClearCart();
      when(() => save(any()))
          .thenAnswer((inv) async => Right(inv.positionalArguments.first as Cart));
      when(() => clear(any())).thenAnswer((_) async => const Right(unit));
    });

    CartCubit build() => CartCubit(load, add, save, clear);
    final cart = Cart.empty.add(tCartRestaurant, tCartItem(qty: 2));

    blocTest<CartCubit, CartState>(
      'loads the persisted cart with totals',
      build: () {
        when(() => load(any())).thenAnswer((_) async => Right(cart));
        return build();
      },
      act: (c) => c.load(),
      expect: () => [
        const CartState.loading(),
        CartState.success(cart: cart, totals: CartCalculator.calculate(cart)),
      ],
    );

    blocTest<CartCubit, CartState>(
      'emits failure when storage fails',
      build: () {
        when(() => load(any())).thenAnswer((_) async => const Left(Failure.cache()));
        return build();
      },
      act: (c) => c.load(),
      expect: () => [const CartState.loading(), const CartState.failure(Failure.cache())],
    );

    blocTest<CartCubit, CartState>(
      'conflict leaves the cart unchanged',
      build: () {
        when(() => add(any())).thenAnswer((_) async => const Right(CartConflict()));
        return build();
      },
      seed: () => CartState.success(cart: cart, totals: CartCalculator.calculate(cart)),
      act: (c) async {
        final result = await c.add(tCartRestaurant.copyWith(id: 'r2'), tCartItem());
        expect(result, isA<CartConflict>());
      },
      expect: () => <CartState>[],
    );

    blocTest<CartCubit, CartState>(
      'changing quantity updates totals immediately',
      build: build,
      seed: () => CartState.success(cart: cart, totals: CartCalculator.calculate(cart)),
      act: (c) => c.changeQuantity(cart.items.single.key, 3),
      expect: () {
        final updated = cart.updateQuantity(cart.items.single.key, 3);
        return [CartState.success(cart: updated, totals: CartCalculator.calculate(updated))];
      },
    );

    blocTest<CartCubit, CartState>(
      'clear empties the cart',
      build: build,
      seed: () => CartState.success(cart: cart, totals: CartCalculator.calculate(cart)),
      act: (c) => c.clear(),
      expect: () => [const CartState.success(cart: Cart.empty, totals: CartTotals.zero)],
    );
  });
}
