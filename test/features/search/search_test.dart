import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_delivery/core/error/failures.dart';
import 'package:food_delivery/features/restaurant/domain/entities/restaurant.dart';
import 'package:food_delivery/features/search/domain/usecases/search_usecases.dart';
import 'package:food_delivery/features/search/presentation/bloc/search_bloc.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/fixtures.dart';
import '../../helpers/mocks.dart';

void main() {
  setUpAll(registerFallbacks);

  group('helpers', () {
    test('normalizeQuery trims, lower-cases and collapses spaces', () {
      expect(normalizeQuery('  Toshkent   OSHI '), 'toshkent oshi');
    });

    test('pushHistory keeps the last 5 unique queries, newest first', () {
      var history = <String>[];
      for (final q in ['a', 'b', 'c', 'd', 'e', 'f', 'B']) {
        history = pushHistory(history, q);
      }
      expect(history, ['B', 'f', 'e', 'd', 'c']);
    });
  });

  group('SearchRestaurants', () {
    late MockSearchRepository repo;
    setUp(() => repo = MockSearchRepository());

    test('ignores too short queries', () async {
      expect(await SearchRestaurants(repo)('a'), isA<Right<Failure, List<Restaurant>>>());
      verifyNever(() => repo.search(any()));
    });

    test('searches the normalized query and saves history', () async {
      when(() => repo.search('osh')).thenAnswer((_) async => Right([tRestaurant()]));
      when(() => repo.addToHistory(any())).thenAnswer((_) async => ['Osh']);
      final result = await SearchRestaurants(repo)(' Osh ');
      expect(result.getRight().toNullable(), hasLength(1));
      verify(() => repo.addToHistory('Osh')).called(1);
    });

    test('does not save history when the search fails', () async {
      when(() => repo.search(any())).thenAnswer((_) async => const Left(Failure.network()));
      await SearchRestaurants(repo)('burger');
      verifyNever(() => repo.addToHistory(any()));
    });
  });

  group('SearchBloc', () {
    late MockSearchRestaurants search;
    late MockGetSearchHistory history;
    late MockClearSearchHistory clear;

    setUp(() {
      search = MockSearchRestaurants();
      history = MockGetSearchHistory();
      clear = MockClearSearchHistory();
      when(() => history()).thenReturn(['pizza']);
      when(() => clear()).thenAnswer((_) async {});
    });

    SearchBloc build() => SearchBloc(search, history, clear);

    blocTest<SearchBloc, SearchState>(
      'shows history on start',
      build: build,
      act: (b) => b.add(const SearchEvent.started()),
      expect: () => [
        const SearchState.initial(['pizza']),
      ],
    );

    blocTest<SearchBloc, SearchState>(
      'debounces typing by 400 ms: only the last query is searched',
      build: () {
        when(() => search(any())).thenAnswer((_) async => Right([tRestaurant()]));
        return build();
      },
      act: (b) async {
        b
          ..add(const SearchEvent.queryChanged('bu'))
          ..add(const SearchEvent.queryChanged('bur'))
          ..add(const SearchEvent.queryChanged('burger'));
      },
      wait: const Duration(milliseconds: 500),
      expect: () => [
        const SearchState.loading('burger'),
        SearchState.success(query: 'burger', results: [tRestaurant()]),
      ],
      verify: (_) => verify(() => search('burger')).called(1),
    );

    blocTest<SearchBloc, SearchState>(
      'history item searches immediately; failure is reported',
      build: () {
        when(() => search(any())).thenAnswer((_) async => const Left(Failure.network()));
        return build();
      },
      act: (b) => b.add(const SearchEvent.submitted('pizza')),
      expect: () => [
        const SearchState.loading('pizza'),
        const SearchState.failure(query: 'pizza', failure: Failure.network()),
      ],
    );

    blocTest<SearchBloc, SearchState>(
      'clearing history',
      build: build,
      act: (b) => b.add(const SearchEvent.historyCleared()),
      expect: () => [const SearchState.initial([])],
      verify: (_) => verify(() => clear()).called(1),
    );
  });
}
