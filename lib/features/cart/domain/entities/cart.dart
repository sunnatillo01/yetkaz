import 'package:food_delivery/features/restaurant/domain/entities/menu_item.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'cart.freezed.dart';

/// Restaurant data the cart needs for totals.
@freezed
abstract class CartRestaurant with _$CartRestaurant {
  const factory CartRestaurant({
    required String id,
    required String name,
    required int deliveryFee,
    required int minOrder,
  }) = _CartRestaurant;
}

@freezed
abstract class CartItem with _$CartItem {
  const factory CartItem({
    required String menuItemId,
    required String name,
    required String imageUrl,
    required int basePrice,
    required int quantity,
    @Default([]) List<MenuOption> options,
  }) = _CartItem;
  const CartItem._();

  /// Same dish with the same extras is merged into one line.
  String get key {
    final names = options.map((o) => o.name).toList()..sort();
    return '$menuItemId|${names.join(',')}';
  }

  int get unitPrice => basePrice + options.fold<int>(0, (s, o) => s + o.price);

  int get lineTotal => unitPrice * quantity;
}

@freezed
abstract class Cart with _$Cart {
  const factory Cart({CartRestaurant? restaurant, @Default([]) List<CartItem> items}) = _Cart;
  const Cart._();

  static const empty = Cart();
  static const maxQuantity = 99;

  bool get isEmpty => items.isEmpty;

  int get itemCount => items.fold(0, (s, i) => s + i.quantity);

  int quantityOf(String menuItemId) =>
      items.where((i) => i.menuItemId == menuItemId).fold(0, (s, i) => s + i.quantity);

  /// Cart may contain dishes of a single restaurant only.
  bool conflictsWith(String restaurantId) =>
      !isEmpty && restaurant != null && restaurant!.id != restaurantId;

  Cart add(CartRestaurant from, CartItem item) {
    final base = conflictsWith(from.id) ? Cart.empty : this;
    final index = base.items.indexWhere((i) => i.key == item.key);
    final updated = [...base.items];
    if (index == -1) {
      updated.add(item);
    } else {
      final merged = (updated[index].quantity + item.quantity).clamp(1, maxQuantity);
      updated[index] = updated[index].copyWith(quantity: merged);
    }
    return Cart(restaurant: from, items: updated);
  }

  Cart updateQuantity(String key, int quantity) {
    if (quantity <= 0) return remove(key);
    return copyWith(
      items: [
        for (final i in items)
          if (i.key == key) i.copyWith(quantity: quantity.clamp(1, maxQuantity)) else i,
      ],
    );
  }

  Cart remove(String key) {
    final updated = items.where((i) => i.key != key).toList();
    return updated.isEmpty ? Cart.empty : copyWith(items: updated);
  }
}
