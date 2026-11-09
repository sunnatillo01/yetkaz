import 'package:food_delivery/core/entities/coordinates.dart';
import 'package:food_delivery/core/error/failures.dart';
import 'package:food_delivery/core/usecase/usecase.dart';
import 'package:food_delivery/features/address/domain/entities/address.dart';
import 'package:fpdart/fpdart.dart';

abstract interface class AddressRepository {
  /// Saved addresses of the signed-in user (`users/{uid}/addresses`).
  Stream<Either<Failure, List<Address>>> watchSaved();

  /// Creates (no id) or updates (with id) an address. Returns it with id.
  FutureEither<Address> save(Address address);

  FutureEither<Unit> delete(String id);

  /// Address used for delivery right now (kept locally).
  Address? current();

  Future<void> setCurrent(Address address);
}

abstract interface class LocationRepository {
  /// Asks for permission when needed. Fails with `Failure.location`.
  FutureEither<Coordinates> currentPosition();

  /// Human readable street address for [point].
  FutureEither<String> reverseGeocode(Coordinates point, {String? languageCode});

  Future<void> openAppSettings();

  Future<void> openLocationSettings();
}
