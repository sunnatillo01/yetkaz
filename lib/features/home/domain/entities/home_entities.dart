import 'package:food_delivery/features/restaurant/domain/entities/restaurant.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'home_entities.freezed.dart';

@freezed
abstract class Category with _$Category {
  const factory Category({
    required String id,
    required Map<String, String> names,
    required String iconUrl,
    @Default(0) int order,
  }) = _Category;
  const Category._();

  /// Localized name with Uzbek fallback.
  String name(String languageCode) =>
      names[languageCode] ?? names['uz'] ?? names.values.firstOrNull ?? id;
}

@freezed
abstract class PromoBanner with _$PromoBanner {
  const factory PromoBanner({
    required String id,
    required String imageUrl,
    String? restaurantId,
    @Default(0) int order,
  }) = _PromoBanner;
}

@freezed
abstract class HomeContent with _$HomeContent {
  const factory HomeContent({
    required List<PromoBanner> banners,
    required List<Category> categories,
  }) = _HomeContent;
}

enum RestaurantSort { popular, nearest, rating }

@freezed
abstract class RestaurantFilter with _$RestaurantFilter {
  const factory RestaurantFilter({
    String? categoryId,
    @Default(false) bool topRated,

    /// `0` = free delivery only, `null` = any.
    int? maxDeliveryFee,
    @Default(RestaurantSort.popular) RestaurantSort sort,
  }) = _RestaurantFilter;
  const RestaurantFilter._();

  static const initial = RestaurantFilter();

  bool get isDefault => this == initial;

  /// Number of active filters (badge on the filter button).
  int get activeCount =>
      (categoryId != null ? 1 : 0) +
      (topRated ? 1 : 0) +
      (maxDeliveryFee != null ? 1 : 0) +
      (sort != RestaurantSort.popular ? 1 : 0);

  /// Client-side check, used for cached/offline data.
  bool matches(Restaurant r) =>
      (categoryId == null || r.categoryIds.contains(categoryId)) &&
      (!topRated || r.rating >= 4) &&
      (maxDeliveryFee == null || r.deliveryFee <= maxDeliveryFee!);
}
