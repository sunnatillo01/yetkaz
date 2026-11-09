import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:food_delivery/core/error/failures.dart';
import 'package:food_delivery/features/address/domain/entities/address.dart';
import 'package:food_delivery/features/cart/domain/entities/cart.dart';
import 'package:food_delivery/features/checkout/domain/usecases/place_order.dart';
import 'package:food_delivery/features/order_tracking/domain/entities/order.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:uuid/uuid.dart';

part 'checkout_bloc.freezed.dart';

@freezed
sealed class CheckoutEvent with _$CheckoutEvent {
  const factory CheckoutEvent.paymentMethodChanged(PaymentMethod method) =
      CheckoutPaymentMethodChanged;
  const factory CheckoutEvent.noteChanged(String note) = CheckoutNoteChanged;
  const factory CheckoutEvent.submitted({required Cart cart, required Address? address}) =
      CheckoutSubmitted;
}

@freezed
sealed class CheckoutStatus with _$CheckoutStatus {
  const factory CheckoutStatus.initial() = CheckoutInitial;
  const factory CheckoutStatus.loading() = CheckoutLoading;
  const factory CheckoutStatus.success(String orderId) = CheckoutSuccess;
  const factory CheckoutStatus.failure(Failure failure) = CheckoutFailure;
}

@freezed
abstract class CheckoutState with _$CheckoutState {
  const factory CheckoutState({
    @Default(PaymentMethod.cash) PaymentMethod paymentMethod,
    @Default('') String note,
    @Default(CheckoutStatus.initial()) CheckoutStatus status,
    @Default(false) bool addressMissing,
  }) = _CheckoutState;
}

/// Double-tap protection is two-fold:
/// 1. `droppable()` ignores new submits while one is in progress;
/// 2. one idempotency key per checkout screen — even a retried request
///    after a timeout cannot create a second order on the server.
@injectable
class CheckoutBloc extends Bloc<CheckoutEvent, CheckoutState> {
  CheckoutBloc(this._placeOrder) : super(const CheckoutState()) {
    on<CheckoutPaymentMethodChanged>((e, emit) => emit(state.copyWith(paymentMethod: e.method)));
    on<CheckoutNoteChanged>((e, emit) => emit(state.copyWith(note: e.note)));
    on<CheckoutSubmitted>(_onSubmitted, transformer: droppable());
  }

  final PlaceOrder _placeOrder;
  final String idempotencyKey = const Uuid().v4();

  Future<void> _onSubmitted(CheckoutSubmitted event, Emitter<CheckoutState> emit) async {
    if (state.status is CheckoutLoading || state.status is CheckoutSuccess) return;
    if (event.address == null) {
      emit(state.copyWith(addressMissing: true));
      emit(state.copyWith(addressMissing: false));
      return;
    }
    emit(state.copyWith(status: const CheckoutStatus.loading()));
    final result = await _placeOrder(
      PlaceOrderParams(
        cart: event.cart,
        address: event.address,
        paymentMethod: state.paymentMethod,
        note: state.note,
        idempotencyKey: idempotencyKey,
      ),
    );
    emit(state.copyWith(status: result.fold(CheckoutStatus.failure, CheckoutStatus.success)));
  }
}
