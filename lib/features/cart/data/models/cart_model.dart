import 'package:food_delivery/features/cart/domain/entities/cart.dart';
import 'package:food_delivery/features/restaurant/data/models/restaurant_model.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'cart_model.freezed.dart';
part 'cart_model.g.dart';

@freezed
abstract class CartItemModel with _$CartItemModel {
  const factory CartItemModel({
    required String menuItemId,
    required String name,
    required String imageUrl,
    required int basePrice,
    required int quantity,
    @Default([]) List<MenuOptionModel> options,
  }) = _CartItemModel;
  const CartItemModel._();

  factory CartItemModel.fromJson(Map<String, dynamic> json) => _$CartItemModelFromJson(json);

  factory CartItemModel.fromEntity(CartItem i) => CartItemModel(
    menuItemId: i.menuItemId,
    name: i.name,
    imageUrl: i.imageUrl,
    basePrice: i.basePrice,
    quantity: i.quantity,
    options: [for (final o in i.options) MenuOptionModel(name: o.name, price: o.price)],
  );

  CartItem toEntity() => CartItem(
    menuItemId: menuItemId,
    name: name,
    imageUrl: imageUrl,
    basePrice: basePrice,
    quantity: quantity,
    options: options.map((o) => o.toEntity()).toList(),
  );
}

/// Persisted in Hive as a JSON string so the cart survives app restarts.
@freezed
abstract class CartModel with _$CartModel {
  const factory CartModel({
    String? restaurantId,
    String? restaurantName,
    @Default(0) int deliveryFee,
    @Default(0) int minOrder,
    @Default([]) List<CartItemModel> items,
  }) = _CartModel;
  const CartModel._();

  factory CartModel.fromJson(Map<String, dynamic> json) => _$CartModelFromJson(json);

  factory CartModel.fromEntity(Cart cart) => CartModel(
    restaurantId: cart.restaurant?.id,
    restaurantName: cart.restaurant?.name,
    deliveryFee: cart.restaurant?.deliveryFee ?? 0,
    minOrder: cart.restaurant?.minOrder ?? 0,
    items: cart.items.map(CartItemModel.fromEntity).toList(),
  );

  Cart toEntity() => Cart(
    restaurant: restaurantId == null
        ? null
        : CartRestaurant(
            id: restaurantId!,
            name: restaurantName ?? '',
            deliveryFee: deliveryFee,
            minOrder: minOrder,
          ),
    items: items.map((i) => i.toEntity()).toList(),
  );
}
