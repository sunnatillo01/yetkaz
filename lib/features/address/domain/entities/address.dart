import 'package:food_delivery/core/entities/coordinates.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'address.freezed.dart';

enum AddressLabel {
  home,
  work,
  other;

  static AddressLabel parse(String? value) =>
      AddressLabel.values.firstWhere((l) => l.name == value, orElse: () => AddressLabel.other);
}

@freezed
abstract class Address with _$Address {
  const factory Address({
    required Coordinates location,
    required String text,
    String? id,
    @Default(AddressLabel.other) AddressLabel label,
    @Default('') String entrance,
    @Default('') String floor,
    @Default('') String apartment,
    @Default('') String note,
  }) = _Address;
  const Address._();

  bool get isSaved => id != null;

  /// "Street 1, entrance 2, floor 3, apt 4" style details for the courier.
  List<String> get details =>
      [entrance, floor, apartment].where((e) => e.trim().isNotEmpty).toList();
}
