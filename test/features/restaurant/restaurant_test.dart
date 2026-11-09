import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_delivery/core/error/exceptions.dart';
import 'package:food_delivery/core/error/failures.dart';
import 'package:food_delivery/features/restaurant/data/datasources/restaurant_remote_data_source.dart';
import 'package:food_delivery/features/restaurant/data/models/restaurant_model.dart';
import 'package:food_delivery/features/restaurant/data/repositories/restaurant_repository_impl.dart';
import 'package:food_delivery/features/restaurant/domain/entities/menu_item.dart';
import 'package:food_delivery/features/restaurant/domain/usecases/get_restaurant_details.dart';
import 'package:food_delivery/features/restaurant/presentation/bloc/restaurant_cubits.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/fixtures.dart';
import '../../helpers/mocks.dart';

class _MockRemote extends Mock implements RestaurantRemoteDataSource;

void main() {
  setUpAll(registerFallbacks);

  group('Restaurant.isOpenAt', () {
    test('regular hours', () {
      final r = tRestaurant();
      expect(r.isOpenAt(DateTime(2026, 1, 1, 8, 59)), isFalse);
      expect(r.isOpenAt(DateTime(2026, 1, 1, 9)), isTrue);
      expect(r.isOpenAt(DateTime(2026, 1, 1, 22, 59)), isTrue);
      expect(r.isOpenAt(DateTime(2026, 1, 1, 23)), isFalse);
    });

    test('overnight hours', () {
      final r = tRestaurant(open: '18:00', close: '03:00');
      expect(r.isOpenAt(DateTime(2026, 1, 1, 12)), isFalse);
      expect(r.isOpenAt(DateTime(2026, 1, 1, 20)), isTrue);
      expect(r.isOpenAt(DateTime(2026, 1, 1, 2)), isTrue);
    });

    test('same open and close means 24/7', () {
      expect(tRestaurant(open: '00:00', close: '00:00').isOpenAt(DateTime(2026)), isTrue);
    });
  });

  test('dishTotal = (base + options) × qty', () {
    expect(dishTotal(basePrice: 30000, optionPrices: [5000, 3000], quantity: 2), 76000);
  });

  test('groupMenu keeps section and item order', () {
    final sections = groupMenu(const [
      MenuItemModel(id: 'c', section: 'Drinks', name: 'Cola', sectionOrder: 1),
      MenuItemModel(id: 'b', section: 'Burgers', name: 'Double', order: 1),
      MenuItemModel(id: 'a', section: 'Burgers', name: 'Classic'),
    ]);
    expect(sections.map((s) => s.title), ['Burgers', 'Drinks']);
    expect(sections.first.items.map((i) => i.id), ['a', 'b']);
  });

  group('RestaurantRepositoryImpl', () {
    late _MockRemote remote;
    setUp(() => remote = _MockRemote());

    test('maps not found', () async {
      when(() => remote.getRestaurant('x')).thenThrow(const NotFoundException());
      final result = await RestaurantRepositoryImpl(remote).getRestaurant('x');
      expect(result, const Left<Failure, dynamic>(Failure.notFound()));
    });

    test('maps the document to the entity', () async {
      when(() => remote.getRestaurant('r1'))
          .thenAnswer((_) async => RestaurantModel.fromEntity(tRestaurant()));
      final result = await RestaurantRepositoryImpl(remote).getRestaurant('r1');
      expect(result.getRight().toNullable(), tRestaurant());
    });
  });

  group('GetRestaurantDetails', () {
    late MockRestaurantRepository repo;
    setUp(() => repo = MockRestaurantRepository());

    test('combines restaurant and menu', () async {
      const sections = [
        MenuSection(title: 'Burgers', items: [tMenuItem]),
      ];
      when(() => repo.getRestaurant('r1')).thenAnswer((_) async => Right(tRestaurant()));
      when(() => repo.getMenu('r1')).thenAnswer((_) async => const Right(sections));
      final result = await GetRestaurantDetails(repo)('r1');
      expect(result.getRight().toNullable()!.sections, sections);
    });

    test('fails if the menu fails', () async {
      when(() => repo.getRestaurant('r1')).thenAnswer((_) async => Right(tRestaurant()));
      when(() => repo.getMenu('r1')).thenAnswer((_) async => const Left(Failure.network()));
      expect((await GetRestaurantDetails(repo)('r1')).isLeft(), isTrue);
    });
  });

  group('RestaurantCubit', () {
    late MockGetRestaurantDetails getDetails;
    late MockClock clock;
    final details = RestaurantDetails(restaurant: tRestaurant(), sections: const []);

    setUp(() {
      getDetails = MockGetRestaurantDetails();
      clock = MockClock();
    });

    blocTest<RestaurantCubit, RestaurantState>(
      'open restaurant',
      build: () {
        when(() => clock.now()).thenReturn(DateTime(2026, 1, 1, 12));
        when(() => getDetails('r1')).thenAnswer((_) async => Right(details));
        return RestaurantCubit(getDetails, clock);
      },
      act: (c) => c.load('r1'),
      expect: () => [
        const RestaurantState.loading(),
        RestaurantState.success(details: details, isOpen: true),
      ],
    );

    blocTest<RestaurantCubit, RestaurantState>(
      'closed restaurant disables ordering',
      build: () {
        when(() => clock.now()).thenReturn(DateTime(2026, 1, 1, 3));
        when(() => getDetails('r1')).thenAnswer((_) async => Right(details));
        return RestaurantCubit(getDetails, clock);
      },
      act: (c) => c.load('r1'),
      expect: () => [
        const RestaurantState.loading(),
        RestaurantState.success(details: details, isOpen: false),
      ],
    );

    blocTest<RestaurantCubit, RestaurantState>(
      'failure and retry',
      build: () {
        when(() => getDetails('r1')).thenAnswer((_) async => const Left(Failure.network()));
        return RestaurantCubit(getDetails, clock);
      },
      act: (c) async {
        await c.load('r1');
        await c.retry();
      },
      expect: () => [
        const RestaurantState.loading(),
        const RestaurantState.failure(Failure.network()),
        const RestaurantState.loading(),
        const RestaurantState.failure(Failure.network()),
      ],
    );
  });

  group('DishCubit', () {
    blocTest<DishCubit, DishState>(
      'toggles options and quantity, price follows',
      build: () => DishCubit(tMenuItem),
      act: (c) => c
        ..toggleOption('Cheese')
        ..setQuantity(3),
      verify: (c) {
        expect(c.state.total, (30000 + 5000) * 3);
        expect(c.state.toCartItem().options, [tCheese]);
      },
    );

    blocTest<DishCubit, DishState>(
      'quantity is clamped to 1..99',
      build: () => DishCubit(tMenuItem),
      act: (c) => c.setQuantity(0),
      verify: (c) => expect(c.state.quantity, 1),
    );

    blocTest<DishCubit, DishState>(
      'toggling twice removes the option',
      build: () => DishCubit(tMenuItem),
      act: (c) => c
        ..toggleOption('Cheese')
        ..toggleOption('Cheese'),
      verify: (c) => expect(c.state.total, 30000),
    );
  });
}
