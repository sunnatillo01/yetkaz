import 'dart:math' as math;

import 'package:freezed_annotation/freezed_annotation.dart';

part 'coordinates.freezed.dart';

/// Pure-Dart geographic point (no dependency on any map SDK).
@freezed
abstract class Coordinates with _$Coordinates {
  const factory Coordinates({required double lat, required double lng}) = _Coordinates;
  const Coordinates._();

  /// Tashkent city centre — default camera position.
  static const tashkent = Coordinates(lat: 41.311081, lng: 69.240562);

  /// Great-circle distance in kilometres (haversine).
  double distanceTo(Coordinates other) {
    const earthRadiusKm = 6371.0;
    final dLat = _rad(other.lat - lat);
    final dLng = _rad(other.lng - lng);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat)) * math.cos(_rad(other.lat)) * math.sin(dLng / 2) * math.sin(dLng / 2);
    return earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  /// Linear interpolation, used to animate the courier marker.
  Coordinates lerp(Coordinates to, double t) =>
      Coordinates(lat: lat + (to.lat - lat) * t, lng: lng + (to.lng - lng) * t);

  /// Initial bearing in degrees (0..360) towards [to].
  double bearingTo(Coordinates to) {
    final phi1 = _rad(lat);
    final phi2 = _rad(to.lat);
    final dLng = _rad(to.lng - lng);
    final y = math.sin(dLng) * math.cos(phi2);
    final x = math.cos(phi1) * math.sin(phi2) - math.sin(phi1) * math.cos(phi2) * math.cos(dLng);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  static double _rad(double deg) => deg * math.pi / 180;
}
