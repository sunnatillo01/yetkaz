import 'package:food_delivery/core/entities/coordinates.dart';
import 'package:food_delivery/core/firebase/json_converters.dart';
import 'package:food_delivery/features/restaurant/domain/entities/menu_item.dart';
import 'package:food_delivery/features/restaurant/domain/entities/restaurant.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'restaurant_model.freezed.dart';
part 'restaurant_model.g.dart';

/// `restaurants/{id}` document. `id` is not stored in the document itself
/// but is kept in JSON for the offline Hive cache.
@freezed
abstract class RestaurantModel with _$RestaurantModel {
  const factory RestaurantModel({
    required String name,
    required String imageUrl,
    @Default('') String id,
    @Default([]) List<String> categoryIds,
    @JsonKey(fromJson: doubleFromJson) @Default(0) double rating,
    @JsonKey(fromJson: intFromJson) @Default(30) int deliveryTimeMin,
    @JsonKey(fromJson: intFromJson) @Default(0) int deliveryFee,
    @JsonKey(fromJson: intFromJson) @Default(0) int minOrder,
    @Default('09:00') String openTime,
    @Default('23:00') String closeTime,
    @JsonKey(fromJson: doubleFromJson) @Default(0) double lat,
    @JsonKey(fromJson: doubleFromJson) @Default(0) double lng,
    @JsonKey(fromJson: intFromJson) @Default(0) int popularity,
  }) = _RestaurantModel;
  const RestaurantModel._();

  factory RestaurantModel.fromJson(Map<String, dynamic> json) => _$RestaurantModelFromJson(json);

  factory RestaurantModel.fromFirestore(String id, Map<String, dynamic> data) =>
      RestaurantModel.fromJson({...data, 'id': id});

  factory RestaurantModel.fromEntity(Restaurant r) => RestaurantModel(
    id: r.id,
    name: r.name,
    imageUrl: r.imageUrl,
    categoryIds: r.categoryIds,
    rating: r.rating,
    deliveryTimeMin: r.deliveryTimeMin,
    deliveryFee: r.deliveryFee,
    minOrder: r.minOrder,
    openTime: r.openTime,
    closeTime: r.closeTime,
    lat: r.location.lat,
    lng: r.location.lng,
    popularity: r.popularity,
  );

  Restaurant toEntity() => Restaurant(
    id: id,
    name: name,
    imageUrl: imageUrl,
    categoryIds: categoryIds,
    rating: rating,
    deliveryTimeMin: deliveryTimeMin,
    deliveryFee: deliveryFee,
    minOrder: minOrder,
    openTime: openTime,
    closeTime: closeTime,
    location: Coordinates(lat: lat, lng: lng),
    popularity: popularity,
  );
}

@freezed
abstract class MenuOptionModel with _$MenuOptionModel {
  const factory MenuOptionModel({
    required String name,
    @JsonKey(fromJson: intFromJson) @Default(0) int price,
  }) = _MenuOptionModel;
  const MenuOptionModel._();

  factory MenuOptionModel.fromJson(Map<String, dynamic> json) => _$MenuOptionModelFromJson(json);

  MenuOption toEntity() => MenuOption(name: name, price: price);
}

/// `restaurants/{id}/menu/{itemId}` document.
@freezed
abstract class MenuItemModel with _$MenuItemModel {
  const factory MenuItemModel({
    required String section,
    required String name,
    @Default('') String id,
    @Default('') String description,
    @JsonKey(fromJson: intFromJson) @Default(0) int price,
    @Default('') String imageUrl,
    @Default([]) List<MenuOptionModel> options,
    @Default(true) bool isAvailable,
    @JsonKey(fromJson: intFromJson) @Default(0) int sectionOrder,
    @JsonKey(fromJson: intFromJson) @Default(0) int order,
  }) = _MenuItemModel;
  const MenuItemModel._();

  factory MenuItemModel.fromJson(Map<String, dynamic> json) => _$MenuItemModelFromJson(json);

  factory MenuItemModel.fromFirestore(String id, Map<String, dynamic> data) =>
      MenuItemModel.fromJson({...data, 'id': id});

  MenuItem toEntity() => MenuItem(
    id: id,
    section: section,
    name: name,
    description: description,
    price: price,
    imageUrl: imageUrl,
    options: options.map((o) => o.toEntity()).toList(),
    isAvailable: isAvailable,
  );
}

/// Groups items into sections preserving `sectionOrder` / `order`.
List<MenuSection> groupMenu(List<MenuItemModel> items) {
  final sorted = [...items]
    ..sort((a, b) {
      final bySection = a.sectionOrder.compareTo(b.sectionOrder);
      return bySection != 0 ? bySection : a.order.compareTo(b.order);
    });
  final sections = <String, List<MenuItem>>{};
  for (final item in sorted) {
    (sections[item.section] ??= []).add(item.toEntity());
  }
  return [for (final e in sections.entries) MenuSection(title: e.key, items: e.value)];
}
