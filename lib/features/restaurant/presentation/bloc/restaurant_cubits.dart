import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:food_delivery/core/error/failures.dart';
import 'package:food_delivery/core/utils/clock.dart';
import 'package:food_delivery/features/cart/domain/entities/cart.dart';
import 'package:food_delivery/features/restaurant/domain/entities/menu_item.dart';
import 'package:food_delivery/features/restaurant/domain/entities/restaurant.dart';
import 'package:food_delivery/features/restaurant/domain/usecases/get_restaurant_details.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'restaurant_cubits.freezed.dart';

@freezed
sealed class RestaurantState with _$RestaurantState {
  const factory RestaurantState.initial() = RestaurantInitial;
  const factory RestaurantState.loading() = RestaurantLoading;
  const factory RestaurantState.success({
    required RestaurantDetails details,
    required bool isOpen,
  }) = RestaurantSuccess;
  const factory RestaurantState.failure(Failure failure) = RestaurantFailure;
}

@injectable
class RestaurantCubit extends Cubit<RestaurantState> {
  RestaurantCubit(this._getDetails, this._clock) : super(const RestaurantState.initial());

  final GetRestaurantDetails _getDetails;
  final Clock _clock;
  late String _id;

  Future<void> load(String restaurantId) async {
    _id = restaurantId;
    emit(const RestaurantState.loading());
    final result = await _getDetails(restaurantId);
    if (isClosed) return;
    emit(
      result.fold(
        RestaurantState.failure,
        (d) => RestaurantState.success(details: d, isOpen: d.restaurant.isOpenAt(_clock.now())),
      ),
    );
  }

  Future<void> retry() => load(_id);
}

extension RestaurantCartX on Restaurant {
  CartRestaurant toCartRestaurant() =>
      CartRestaurant(id: id, name: name, deliveryFee: deliveryFee, minOrder: minOrder);
}

@freezed
abstract class DishState with _$DishState {
  const factory DishState({
    required MenuItem item,
    @Default({}) Set<String> selectedOptions,
    @Default(1) int quantity,
  }) = _DishState;
  const DishState._();

  List<MenuOption> get options =>
      item.options.where((o) => selectedOptions.contains(o.name)).toList();

  int get total => dishTotal(
    basePrice: item.price,
    optionPrices: options.map((o) => o.price),
    quantity: quantity,
  );

  CartItem toCartItem() => CartItem(
    menuItemId: item.id,
    name: item.name,
    imageUrl: item.imageUrl,
    basePrice: item.price,
    quantity: quantity,
    options: options,
  );
}

/// State of the dish details bottom sheet: extras + quantity.
@injectable
class DishCubit extends Cubit<DishState> {
  DishCubit(@factoryParam MenuItem item) : super(DishState(item: item));

  void toggleOption(String name) {
    final selected = {...state.selectedOptions};
    if (!selected.remove(name)) selected.add(name);
    emit(state.copyWith(selectedOptions: selected));
  }

  void setQuantity(int quantity) =>
      emit(state.copyWith(quantity: quantity.clamp(1, Cart.maxQuantity)));
}
