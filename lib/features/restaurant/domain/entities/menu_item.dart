import 'package:food_delivery/features/restaurant/domain/entities/restaurant.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'menu_item.freezed.dart';

/// Paid extra for a dish, e.g. "Cheese +5 000".
@freezed
abstract class MenuOption with _$MenuOption {
  const factory MenuOption({required String name, required int price}) = _MenuOption;
}

@freezed
abstract class MenuItem with _$MenuItem {
  const factory MenuItem({
    required String id,
    required String section,
    required String name,
    required String description,
    required int price,
    required String imageUrl,
    @Default([]) List<MenuOption> options,
    @Default(true) bool isAvailable,
  }) = _MenuItem;
}

@freezed
abstract class MenuSection with _$MenuSection {
  const factory MenuSection({required String title, required List<MenuItem> items}) = _MenuSection;
}

@freezed
abstract class RestaurantDetails with _$RestaurantDetails {
  const factory RestaurantDetails({
    required Restaurant restaurant,
    required List<MenuSection> sections,
  }) = _RestaurantDetails;
}
