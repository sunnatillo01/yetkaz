import 'package:food_delivery/core/firebase/json_converters.dart';
import 'package:food_delivery/features/home/domain/entities/home_entities.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'home_models.freezed.dart';
part 'home_models.g.dart';

/// `categories/{id}`; `name` is a map `{uz, ru, en}`.
@freezed
abstract class CategoryModel with _$CategoryModel {
  const factory CategoryModel({
    @Default('') String id,
    @Default({}) Map<String, String> name,
    @Default('') String iconUrl,
    @JsonKey(fromJson: intFromJson) @Default(0) int order,
  }) = _CategoryModel;
  const CategoryModel._();

  factory CategoryModel.fromJson(Map<String, dynamic> json) => _$CategoryModelFromJson(json);

  Category toEntity() => Category(id: id, names: name, iconUrl: iconUrl, order: order);
}

/// `banners/{id}`.
@freezed
abstract class BannerModel with _$BannerModel {
  const factory BannerModel({
    required String imageUrl,
    @Default('') String id,
    String? restaurantId,
    @JsonKey(fromJson: intFromJson) @Default(0) int order,
    @Default(true) bool isActive,
  }) = _BannerModel;
  const BannerModel._();

  factory BannerModel.fromJson(Map<String, dynamic> json) => _$BannerModelFromJson(json);

  PromoBanner toEntity() =>
      PromoBanner(id: id, imageUrl: imageUrl, restaurantId: restaurantId, order: order);
}
