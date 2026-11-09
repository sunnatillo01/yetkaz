import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:food_delivery/core/entities/paginated_list.dart';
import 'package:food_delivery/core/error/failures.dart';
import 'package:food_delivery/core/usecase/usecase.dart';
import 'package:food_delivery/features/auth/domain/usecases/auth_usecases.dart';
import 'package:food_delivery/features/cart/domain/entities/cart.dart';
import 'package:food_delivery/features/order_tracking/domain/entities/order.dart';
import 'package:food_delivery/features/order_tracking/domain/usecases/order_usecases.dart';
import 'package:food_delivery/features/profile/domain/repositories/profile_repository.dart';
import 'package:food_delivery/features/profile/domain/usecases/profile_usecases.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'profile_cubits.freezed.dart';

/// Result of profile actions (avatar upload, logout, delete account).
@freezed
sealed class ProfileState with _$ProfileState {
  const factory ProfileState.initial() = ProfileInitial;
  const factory ProfileState.loading() = ProfileLoading;
  const factory ProfileState.success() = ProfileSuccess;
  const factory ProfileState.failure(Failure failure) = ProfileFailure;
}

@injectable
class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit(this._changeAvatar, this._logout, this._deleteAccount)
    : super(const ProfileState.initial());

  final ChangeAvatar _changeAvatar;
  final Logout _logout;
  final DeleteAccount _deleteAccount;

  Future<void> changeAvatar(AvatarSource source) async {
    if (state is ProfileLoading) return;
    emit(const ProfileState.loading());
    final result = await _changeAvatar(source);
    if (isClosed) return;
    emit(result.fold(ProfileState.failure, (_) => const ProfileState.success()));
  }

  Future<void> logout() async {
    emit(const ProfileState.loading());
    final result = await _logout(const NoParams());
    if (isClosed) return;
    emit(result.fold(ProfileState.failure, (_) => const ProfileState.success()));
  }

  Future<void> deleteAccount() async {
    emit(const ProfileState.loading());
    final result = await _deleteAccount(const NoParams());
    if (isClosed) return;
    emit(result.fold(ProfileState.failure, (_) => const ProfileState.success()));
  }
}

@freezed
sealed class OrdersHistoryEvent with _$OrdersHistoryEvent {
  const factory OrdersHistoryEvent.started() = OrdersHistoryStarted;
  const factory OrdersHistoryEvent.nextPageRequested() = OrdersHistoryNextPage;
}

@freezed
sealed class OrdersHistoryState with _$OrdersHistoryState {
  const factory OrdersHistoryState.initial() = OrdersHistoryInitial;
  const factory OrdersHistoryState.loading() = OrdersHistoryLoading;
  const factory OrdersHistoryState.success({
    required List<FoodOrder> orders,
    required bool hasMore,
    PageCursor? cursor,
    @Default(false) bool isLoadingMore,
    Failure? loadMoreFailure,
  }) = OrdersHistorySuccess;
  const factory OrdersHistoryState.failure(Failure failure) = OrdersHistoryFailure;
}

enum OrdersTab { active, completed }

/// One instance per tab (active / completed).
@injectable
class OrdersHistoryBloc extends Bloc<OrdersHistoryEvent, OrdersHistoryState> {
  OrdersHistoryBloc(this._getOrders, @factoryParam this.tab)
    : super(const OrdersHistoryState.initial()) {
    on<OrdersHistoryStarted>(_onStarted, transformer: restartable());
    on<OrdersHistoryNextPage>(_onNextPage, transformer: droppable());
  }

  final GetOrders _getOrders;
  final OrdersTab? tab;

  bool get _active => tab != OrdersTab.completed;

  Future<void> _onStarted(OrdersHistoryStarted event, Emitter<OrdersHistoryState> emit) async {
    emit(const OrdersHistoryState.loading());
    final result = await _getOrders(GetOrdersParams(active: _active));
    emit(
      result.fold(
        OrdersHistoryState.failure,
        (page) => OrdersHistoryState.success(
          orders: page.items,
          hasMore: page.hasMore,
          cursor: page.nextCursor,
        ),
      ),
    );
  }

  Future<void> _onNextPage(OrdersHistoryNextPage event, Emitter<OrdersHistoryState> emit) async {
    final current = state;
    if (current is! OrdersHistorySuccess || !current.hasMore) return;
    emit(current.copyWith(isLoadingMore: true, loadMoreFailure: null));
    final result = await _getOrders(GetOrdersParams(active: _active, cursor: current.cursor));
    emit(
      result.fold(
        (f) => current.copyWith(isLoadingMore: false, loadMoreFailure: f),
        (page) => current.copyWith(
          orders: [...current.orders, ...page.items],
          hasMore: page.hasMore,
          cursor: page.nextCursor,
          isLoadingMore: false,
        ),
      ),
    );
  }
}

@freezed
sealed class ReorderState with _$ReorderState {
  const factory ReorderState.initial() = ReorderInitial;
  const factory ReorderState.loading(String orderId) = ReorderLoading;
  const factory ReorderState.success(Cart cart) = ReorderSuccess;
  const factory ReorderState.failure(Failure failure) = ReorderFailure;
}

@injectable
class ReorderCubit extends Cubit<ReorderState> {
  ReorderCubit(this._reorder) : super(const ReorderState.initial());

  final Reorder _reorder;

  Future<void> reorder(FoodOrder order) async {
    if (state is ReorderLoading) return;
    emit(ReorderState.loading(order.id));
    final result = await _reorder(order);
    if (isClosed) return;
    emit(result.fold(ReorderState.failure, ReorderState.success));
  }
}
