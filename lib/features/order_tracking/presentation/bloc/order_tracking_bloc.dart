import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:food_delivery/core/error/failures.dart';
import 'package:food_delivery/features/order_tracking/domain/entities/order.dart';
import 'package:food_delivery/features/order_tracking/domain/usecases/order_usecases.dart';
import 'package:fpdart/fpdart.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'order_tracking_bloc.freezed.dart';

@freezed
sealed class OrderTrackingEvent with _$OrderTrackingEvent {
  const factory OrderTrackingEvent.started(String orderId) = OrderTrackingStarted;

  /// App went to background — stop listening to Firestore.
  const factory OrderTrackingEvent.paused() = OrderTrackingPaused;

  /// App is visible again — reconnect.
  const factory OrderTrackingEvent.resumed() = OrderTrackingResumed;
  const factory OrderTrackingEvent.cancelRequested() = OrderTrackingCancelRequested;
  const factory OrderTrackingEvent.updated(Either<Failure, FoodOrder> result) =
      OrderTrackingUpdated;
}

@freezed
sealed class OrderTrackingState with _$OrderTrackingState {
  const factory OrderTrackingState.initial() = OrderTrackingInitial;
  const factory OrderTrackingState.loading() = OrderTrackingLoading;
  const factory OrderTrackingState.success({
    required FoodOrder order,
    @Default(false) bool isCancelling,
    Failure? actionFailure,
  }) = OrderTrackingSuccess;
  const factory OrderTrackingState.failure(Failure failure) = OrderTrackingFailure;
}

/// Subscribes to `orders/{id}` snapshots. The subscription lives only while
/// the app is in the foreground to save battery and Firestore reads.
@injectable
class OrderTrackingBloc extends Bloc<OrderTrackingEvent, OrderTrackingState> {
  OrderTrackingBloc(this._watchOrder, this._cancelOrder)
    : super(const OrderTrackingState.initial()) {
    on<OrderTrackingStarted>(_onStarted);
    on<OrderTrackingPaused>((_, _) => _unsubscribe());
    on<OrderTrackingResumed>((_, _) => _subscribe());
    on<OrderTrackingUpdated>(_onUpdated);
    on<OrderTrackingCancelRequested>(_onCancel, transformer: droppable());
  }

  final WatchOrder _watchOrder;
  final CancelOrder _cancelOrder;
  String? _orderId;
  // Cancelled in _unsubscribe(), called on pause, final status and close().
  // ignore: cancel_subscriptions
  StreamSubscription<Either<Failure, FoodOrder>>? _subscription;

  bool get isListening => _subscription != null;

  void _onStarted(OrderTrackingStarted event, Emitter<OrderTrackingState> emit) {
    _orderId = event.orderId;
    emit(const OrderTrackingState.loading());
    _subscribe();
  }

  void _subscribe() {
    final id = _orderId;
    if (id == null || _subscription != null) return;
    _subscription = _watchOrder(id).listen((r) => add(OrderTrackingEvent.updated(r)));
  }

  Future<void> _unsubscribe() async {
    // Clear first: a `resumed` event handled while `cancel()` is still
    // pending must be able to subscribe again.
    final subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
  }

  void _onUpdated(OrderTrackingUpdated event, Emitter<OrderTrackingState> emit) {
    event.result.fold(
      (f) {
        // Keep the last known order on screen if the stream hiccups.
        if (state is! OrderTrackingSuccess) emit(OrderTrackingState.failure(f));
      },
      (order) {
        final current = state;
        emit(
          current is OrderTrackingSuccess
              ? current.copyWith(order: order)
              : OrderTrackingState.success(order: order),
        );
        // Nothing more will change after delivery/cancellation.
        if (order.status.isFinal) unawaited(_unsubscribe());
      },
    );
  }

  Future<void> _onCancel(
    OrderTrackingCancelRequested event,
    Emitter<OrderTrackingState> emit,
  ) async {
    final current = state;
    if (current is! OrderTrackingSuccess) return;
    emit(current.copyWith(isCancelling: true, actionFailure: null));
    final result = await _cancelOrder(current.order);
    final latest = state;
    if (latest is! OrderTrackingSuccess) return;
    emit(latest.copyWith(isCancelling: false, actionFailure: result.fold((f) => f, (_) => null)));
  }

  /// Retry after an initial failure.
  void retry() {
    final id = _orderId;
    if (id == null) return;
    unawaited(_unsubscribe().then((_) => add(OrderTrackingEvent.started(id))));
  }

  @override
  Future<void> close() async {
    await _unsubscribe();
    return super.close();
  }
}
