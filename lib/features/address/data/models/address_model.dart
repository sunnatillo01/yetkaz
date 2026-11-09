import 'package:food_delivery/core/entities/coordinates.dart';
import 'package:food_delivery/core/firebase/json_converters.dart';
import 'package:food_delivery/features/address/domain/entities/address.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'address_model.freezed.dart';
part 'address_model.g.dart';

/// `users/{uid}/addresses/{id}`. Also embedded into `orders/{id}.address`.
@freezed
abstract class AddressModel with _$AddressModel {
  const factory AddressModel({
    @JsonKey(fromJson: doubleFromJson) required double lat,
    @JsonKey(fromJson: doubleFromJson) required double lng,
    required String text,
    String? id,
    @Default('other') String title,
    @Default('') String entrance,
    @Default('') String floor,
    @Default('') String apartment,
    @Default('') String note,
  }) = _AddressModel;
  const AddressModel._();

  factory AddressModel.fromJson(Map<String, dynamic> json) => _$AddressModelFromJson(json);

  factory AddressModel.fromEntity(Address a) => AddressModel(
    id: a.id,
    lat: a.location.lat,
    lng: a.location.lng,
    text: a.text,
    title: a.label.name,
    entrance: a.entrance,
    floor: a.floor,
    apartment: a.apartment,
    note: a.note,
  );

  Address toEntity() => Address(
    id: id,
    location: Coordinates(lat: lat, lng: lng),
    text: text,
    label: AddressLabel.parse(title),
    entrance: entrance,
    floor: floor,
    apartment: apartment,
    note: note,
  );

  /// Firestore payload without the id (it is the document id).
  Map<String, dynamic> toFirestore() => toJson()..remove('id');
}
