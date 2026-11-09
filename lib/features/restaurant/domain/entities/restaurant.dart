import 'package:food_delivery/core/entities/coordinates.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'restaurant.freezed.dart';

@freezed
abstract class Restaurant with _$Restaurant {
  const factory Restaurant({
    required String id,
    required String name,
    required String imageUrl,
    required List<String> categoryIds,
    required double rating,
    required int deliveryTimeMin,
    required int deliveryFee,
    required int minOrder,
    required String openTime,
    required String closeTime,
    required Coordinates location,
    @Default(0) int popularity,
  }) = _Restaurant;
  const Restaurant._();

  /// Working hours are `HH:mm` in local (Tashkent) time.
  /// Supports overnight schedules, e.g. `18:00 – 03:00`.
  bool isOpenAt(DateTime time) {
    final open = _minutes(openTime);
    final close = _minutes(closeTime);
    final now = time.hour * 60 + time.minute;
    if (open == close) return true; // 24/7
    if (open < close) return now >= open && now < close;
    return now >= open || now < close;
  }

  bool get hasFreeDelivery => deliveryFee == 0;

  static int _minutes(String hhmm) {
    final parts = hhmm.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }
}
