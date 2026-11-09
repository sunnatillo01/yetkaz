import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:food_delivery/core/entities/paginated_list.dart';
import 'package:food_delivery/core/error/failures.dart';
import 'package:food_delivery/features/address/domain/usecases/address_usecases.dart';
import 'package:food_delivery/features/home/domain/entities/home_entities.dart';
import 'package:food_delivery/features/home/domain/usecases/home_usecases.dart';
import 'package:food_delivery/features/restaurant/domain/entities/restaurant.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'restaurants_bloc.freezed.dart';

@freezed
sealed class RestaurantsEvent with _$RestaurantsEvent {
  const factory RestaurantsEvent.started() = RestaurantsStarted;

  /// Pull-to-refresh; [completer] finishes the refresh indicator.
  const factory RestaurantsEvent.refreshed({Completer<void>? completer}) = RestaurantsRefreshed;
  const factory RestaurantsEvent.nextPageRequested() = RestaurantsNextPageRequested;
  const factory RestaurantsEvent.filterChanged(RestaurantFilter filter) = RestaurantsFilterChanged;
}

@freezed
sealed class RestaurantsState with _$RestaurantsState {
  const factory RestaurantsState.initial() = RestaurantsInitial;
  const factory RestaurantsState.loading(RestaurantFilter filter) = RestaurantsLoading;
  const factory RestaurantsState.success({
    required List<Restaurant> items,
    required RestaurantFilter filter,
    required bool hasMore,
    PageCursor? cursor,
    @Default(false) bool isLoadingMore,

    /// Error of the *next* page only — shown as a small retry button.
    Failure? loadMoreFailure,
    @Default(false) bool fromCache,
  }) = RestaurantsSuccess;
  const factory RestaurantsState.failure({
    required Failure failure,
    required RestaurantFilter filter,
  }) = RestaurantsFailure;
}

extension RestaurantsStateX on RestaurantsState {
  RestaurantFilter get filter => switch (this) {
    RestaurantsInitial() => RestaurantFilter.initial,
    RestaurantsLoading(:final filter) => filter,
    RestaurantsSuccess(:final filter) => filter,
    RestaurantsFailure(:final filter) => filter,
  };
}

/// Restaurant list: pages of 10, infinite scroll, pull-to-refresh, filters.
@injectable
class RestaurantsBloc extends Bloc<RestaurantsEvent, RestaurantsState> {
  RestaurantsBloc(this._getRestaurants, this._getCurrentAddress)
    : super(const RestaurantsState.initial()) {
    on<RestaurantsStarted>((_, emit) => _loadFirst(emit, state.filter));
    on<RestaurantsFilterChanged>(
      (e, emit) => _loadFirst(emit, e.filter),
      transformer: restartable(),
    );
    on<RestaurantsRefreshed>(_onRefresh, transformer: droppable());
    on<RestaurantsNextPageRequested>(_onNextPage, transformer: droppable());
  }

  final GetRestaurants _getRestaurants;
  final GetCurrentAddress _getCurrentAddress;

  GetRestaurantsParams _params(RestaurantFilter filter, [PageCursor? cursor]) =>
      GetRestaurantsParams(filter: filter, cursor: cursor, near: _getCurrentAddress()?.location);

  Future<void> _loadFirst(
    Emitter<RestaurantsState> emit,
    RestaurantFilter filter, {
    bool showLoader = true,
  }) async {
    if (showLoader) emit(RestaurantsState.loading(filter));
    final result = await _getRestaurants(_params(filter));
    result.fold(
      (f) {
        // On refresh failure keep the list that is already on screen.
        if (!showLoader && state is RestaurantsSuccess) return;
        emit(RestaurantsState.failure(failure: f, filter: filter));
      },
      (page) => emit(
        RestaurantsState.success(
          items: page.items,
          filter: filter,
          hasMore: page.hasMore,
          cursor: page.nextCursor,
          fromCache: page.fromCache,
        ),
      ),
    );
  }

  Future<void> _onRefresh(RestaurantsRefreshed event, Emitter<RestaurantsState> emit) async {
    await _loadFirst(emit, state.filter, showLoader: state is! RestaurantsSuccess);
    event.completer?.complete();
  }

  Future<void> _onNextPage(
    RestaurantsNextPageRequested event,
    Emitter<RestaurantsState> emit,
  ) async {
    final current = state;
    if (current is! RestaurantsSuccess || !current.hasMore || current.isLoadingMore) {
      return;
    }
    emit(current.copyWith(isLoadingMore: true, loadMoreFailure: null));
    final result = await _getRestaurants(_params(current.filter, current.cursor));
    result.fold(
      (f) => emit(current.copyWith(isLoadingMore: false, loadMoreFailure: f)),
      (page) => emit(
        current.copyWith(
          items: [...current.items, ...page.items],
          hasMore: page.hasMore,
          cursor: page.nextCursor,
          isLoadingMore: false,
          loadMoreFailure: null,
        ),
      ),
    );
  }
}
