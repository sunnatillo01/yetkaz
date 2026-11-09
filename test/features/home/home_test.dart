import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_delivery/core/entities/coordinates.dart';
import 'package:food_delivery/core/entities/paginated_list.dart';
import 'package:food_delivery/core/error/exceptions.dart';
import 'package:food_delivery/core/error/failures.dart';
import 'package:food_delivery/core/usecase/usecase.dart';
import 'package:food_delivery/features/home/data/datasources/home_data_sources.dart';
import 'package:food_delivery/features/home/data/repositories/home_repository_impl.dart';
import 'package:food_delivery/features/home/domain/entities/home_entities.dart';
import 'package:food_delivery/features/home/domain/usecases/home_usecases.dart';
import 'package:food_delivery/features/home/presentation/bloc/home_cubit.dart';
import 'package:food_delivery/features/home/presentation/bloc/restaurants_bloc.dart';
import 'package:food_delivery/features/restaurant/data/models/restaurant_model.dart';
import 'package:food_delivery/features/restaurant/domain/entities/restaurant.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/fixtures.dart';
import '../../helpers/mocks.dart';

class _MockRemote extends Mock implements HomeRemoteDataSource;

class _MockLocal extends Mock implements HomeLocalDataSource;

List<Restaurant> _restaurants(int count, {int start = 0}) => [
  for (var i = start; i < start + count; i++) tRestaurant(id: 'r$i'),
];

PaginatedList<Restaurant> _page(List<Restaurant> items, {bool hasMore = true}) =>
    PaginatedList(items: items, hasMore: hasMore, nextCursor: PageCursor(['doc', items.last.id]));

void main() {
  setUpAll(registerFallbacks);

  group('RestaurantFilter', () {
    test('counts active filters and matches restaurants offline', () {
      const filter = RestaurantFilter(categoryId: 'pizza', topRated: true, maxDeliveryFee: 0);
      expect(filter.activeCount, 3);
      expect(filter.isDefault, isFalse);
      expect(filter.matches(tRestaurant(deliveryFee: 0)), isTrue);
      expect(filter.matches(tRestaurant()), isFalse);
      expect(filter.matches(tRestaurant(deliveryFee: 0, rating: 3.5)), isFalse);
      expect(RestaurantFilter.initial.matches(tRestaurant()), isTrue);
    });

    test('category name is localized with fallback', () {
      expect(tCategory.name('ru'), 'Пицца');
      expect(tCategory.name('de'), 'Pitsa');
    });
  });

  group('pagination helpers', () {
    test('pageOf slices the list and exposes the next offset', () {
      final all = List.generate(25, (i) => i);
      final first = pageOf(all, offset: 0, limit: 10);
      expect(first.items, List.generate(10, (i) => i));
      expect(first.hasMore, isTrue);
      expect(first.nextCursor, const PageCursor(['offset', 10]));
      final last = pageOf(all, offset: 20, limit: 10);
      expect(last.items, hasLength(5));
      expect(last.hasMore, isFalse);
    });

    test('sortByDistance puts the nearest first', () {
      const me = Coordinates(lat: 41.30, lng: 69.20);
      final far = tRestaurant(id: 'far', location: const Coordinates(lat: 41.40, lng: 69.40));
      final near = tRestaurant(id: 'near', location: const Coordinates(lat: 41.301, lng: 69.201));
      expect(sortByDistance([far, near], me).first.id, 'near');
    });
  });

  group('GetHomeContent', () {
    test('sorts banners and categories by order', () async {
      final repo = MockHomeRepository();
      when(repo.getBanners).thenAnswer(
        (_) async => const Right([
          PromoBanner(id: 'b2', imageUrl: '', order: 2),
          PromoBanner(id: 'b1', imageUrl: '', order: 1),
        ]),
      );
      when(repo.getCategories).thenAnswer((_) async => const Right([tCategory]));
      final content = (await GetHomeContent(repo)(const NoParams())).getRight().toNullable()!;
      expect(content.banners.map((b) => b.id), ['b1', 'b2']);
    });
  });

  group('HomeRepositoryImpl', () {
    late _MockRemote remote;
    late _MockLocal local;
    late MockNetworkInfo network;
    late HomeRepositoryImpl repo;

    setUp(() {
      remote = _MockRemote();
      local = _MockLocal();
      network = MockNetworkInfo();
      repo = HomeRepositoryImpl(remote, local, network);
      when(() => local.cacheRestaurants(any())).thenAnswer((_) async {});
    });

    final models = [for (final r in _restaurants(10)) RestaurantModel.fromEntity(r)];

    test('online: loads a page and caches the default first page', () async {
      when(() => network.isConnected).thenAnswer((_) async => true);
      when(() => remote.getRestaurants(filter: any(named: 'filter'), limit: 10))
          .thenAnswer((_) async => models);
      final page = (await repo.getRestaurants(filter: RestaurantFilter.initial))
          .getRight()
          .toNullable()!;
      expect(page.items, hasLength(10));
      expect(page.hasMore, isTrue);
      expect(page.nextCursor, const PageCursor(['doc', 'r9']));
      verify(() => local.cacheRestaurants(models)).called(1);
    });

    test('offline: shows the cached first page', () async {
      when(() => network.isConnected).thenAnswer((_) async => false);
      when(() => local.cachedRestaurants()).thenReturn(models);
      final page = (await repo.getRestaurants(filter: RestaurantFilter.initial))
          .getRight()
          .toNullable()!;
      expect(page.fromCache, isTrue);
      expect(page.hasMore, isFalse);
      verifyNever(
        () => remote.getRestaurants(
          filter: any(named: 'filter'),
          limit: any(named: 'limit'),
        ),
      );
    });

    test('offline without cache is a network failure', () async {
      when(() => network.isConnected).thenAnswer((_) async => false);
      when(() => local.cachedRestaurants()).thenThrow(const CacheException());
      final result = await repo.getRestaurants(filter: RestaurantFilter.initial);
      expect(result, const Left<Failure, dynamic>(Failure.network()));
    });

    test('nearest sort pages through a distance-sorted pool', () async {
      when(() => network.isConnected).thenAnswer((_) async => true);
      when(
        () => remote.getRestaurants(
          filter: any(named: 'filter'),
          limit: HomeRepositoryImpl.nearestPoolSize,
        ),
      ).thenAnswer((_) async => models);
      final first = (await repo.getRestaurants(
        filter: const RestaurantFilter(sort: RestaurantSort.nearest),
        near: Coordinates.tashkent,
        limit: 4,
      )).getRight().toNullable()!;
      expect(first.items, hasLength(4));
      expect(first.nextCursor, const PageCursor(['offset', 4]));
      final second = (await repo.getRestaurants(
        filter: const RestaurantFilter(sort: RestaurantSort.nearest),
        near: Coordinates.tashkent,
        limit: 4,
        cursor: first.nextCursor,
      )).getRight().toNullable()!;
      expect(second.items.toSet().intersection(first.items.toSet()), isEmpty);
    });
  });

  group('HomeCubit', () {
    late MockGetHomeContent getContent;
    const content = HomeContent(banners: [tBanner], categories: [tCategory]);
    setUp(() => getContent = MockGetHomeContent());

    blocTest<HomeCubit, HomeState>(
      'loads banners and categories',
      build: () {
        when(() => getContent(any())).thenAnswer((_) async => const Right(content));
        return HomeCubit(getContent);
      },
      act: (c) => c.load(),
      expect: () => [const HomeState.loading(), const HomeState.success(content)],
    );

    blocTest<HomeCubit, HomeState>(
      'shows failure',
      build: () {
        when(() => getContent(any())).thenAnswer((_) async => const Left(Failure.server()));
        return HomeCubit(getContent);
      },
      act: (c) => c.load(),
      expect: () => [const HomeState.loading(), const HomeState.failure(Failure.server())],
    );

    blocTest<HomeCubit, HomeState>(
      'silent refresh keeps old content on failure',
      build: () {
        when(() => getContent(any())).thenAnswer((_) async => const Left(Failure.network()));
        return HomeCubit(getContent);
      },
      seed: () => const HomeState.success(content),
      act: (c) => c.load(silent: true),
      expect: () => <HomeState>[],
    );
  });

  group('RestaurantsBloc', () {
    late MockGetRestaurants getRestaurants;
    late MockGetCurrentAddress getAddress;

    setUp(() {
      getRestaurants = MockGetRestaurants();
      getAddress = MockGetCurrentAddress();
      when(() => getAddress()).thenReturn(null);
    });

    RestaurantsBloc build() => RestaurantsBloc(getRestaurants, getAddress);
    final page1 = _page(_restaurants(10));
    final page2 = _page(_restaurants(3, start: 10), hasMore: false);

    blocTest<RestaurantsBloc, RestaurantsState>(
      'loads the first page',
      build: () {
        when(() => getRestaurants(any())).thenAnswer((_) async => Right(page1));
        return build();
      },
      act: (b) => b.add(const RestaurantsEvent.started()),
      expect: () => [
        const RestaurantsState.loading(RestaurantFilter.initial),
        RestaurantsState.success(
          items: page1.items,
          filter: RestaurantFilter.initial,
          hasMore: true,
          cursor: page1.nextCursor,
        ),
      ],
    );

    blocTest<RestaurantsBloc, RestaurantsState>(
      'appends the next page (infinite scroll)',
      build: () {
        when(() => getRestaurants(any())).thenAnswer((_) async => Right(page2));
        return build();
      },
      seed: () => RestaurantsState.success(
        items: page1.items,
        filter: RestaurantFilter.initial,
        hasMore: true,
        cursor: page1.nextCursor,
      ),
      act: (b) => b.add(const RestaurantsEvent.nextPageRequested()),
      skip: 1,
      expect: () => [
        RestaurantsState.success(
          items: [...page1.items, ...page2.items],
          filter: RestaurantFilter.initial,
          hasMore: false,
          cursor: page2.nextCursor,
        ),
      ],
    );

    blocTest<RestaurantsBloc, RestaurantsState>(
      'next page error keeps the list and shows a small retry',
      build: () {
        when(() => getRestaurants(any())).thenAnswer((_) async => const Left(Failure.network()));
        return build();
      },
      seed: () => RestaurantsState.success(
        items: page1.items,
        filter: RestaurantFilter.initial,
        hasMore: true,
        cursor: page1.nextCursor,
      ),
      act: (b) => b.add(const RestaurantsEvent.nextPageRequested()),
      skip: 1,
      expect: () => [
        RestaurantsState.success(
          items: page1.items,
          filter: RestaurantFilter.initial,
          hasMore: true,
          cursor: page1.nextCursor,
          loadMoreFailure: const Failure.network(),
        ),
      ],
    );

    blocTest<RestaurantsBloc, RestaurantsState>(
      'does not request more when everything is loaded',
      build: build,
      seed: () => RestaurantsState.success(
        items: page1.items,
        filter: RestaurantFilter.initial,
        hasMore: false,
      ),
      act: (b) => b.add(const RestaurantsEvent.nextPageRequested()),
      expect: () => <RestaurantsState>[],
    );

    blocTest<RestaurantsBloc, RestaurantsState>(
      'changing the filter reloads from the first page',
      build: () {
        when(() => getRestaurants(any())).thenAnswer((_) async => Right(page2));
        return build();
      },
      act: (b) => b.add(const RestaurantsEvent.filterChanged(RestaurantFilter(topRated: true))),
      expect: () => [
        const RestaurantsState.loading(RestaurantFilter(topRated: true)),
        RestaurantsState.success(
          items: page2.items,
          filter: const RestaurantFilter(topRated: true),
          hasMore: false,
          cursor: page2.nextCursor,
        ),
      ],
      verify: (_) {
        final p =
            verify(() => getRestaurants(captureAny())).captured.single as GetRestaurantsParams;
        expect(p.cursor, isNull);
        expect(p.filter.topRated, isTrue);
      },
    );

    blocTest<RestaurantsBloc, RestaurantsState>(
      'empty result is a success with no items',
      build: () {
        when(() => getRestaurants(any()))
            .thenAnswer((_) async => const Right(PaginatedList(items: [], hasMore: false)));
        return build();
      },
      act: (b) => b.add(const RestaurantsEvent.started()),
      skip: 1,
      expect: () => [
        const RestaurantsState.success(items: [], filter: RestaurantFilter.initial, hasMore: false),
      ],
    );

    blocTest<RestaurantsBloc, RestaurantsState>(
      'failed pull-to-refresh keeps the list on screen',
      build: () {
        when(() => getRestaurants(any())).thenAnswer((_) async => const Left(Failure.network()));
        return build();
      },
      seed: () => RestaurantsState.success(
        items: page1.items,
        filter: RestaurantFilter.initial,
        hasMore: true,
      ),
      act: (b) => b.add(const RestaurantsEvent.refreshed()),
      expect: () => <RestaurantsState>[],
    );
  });
}
