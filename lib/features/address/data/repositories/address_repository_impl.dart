import 'package:food_delivery/core/entities/coordinates.dart';
import 'package:food_delivery/core/error/exception_mapper.dart';
import 'package:food_delivery/core/error/failures.dart';
import 'package:food_delivery/core/usecase/usecase.dart';
import 'package:food_delivery/features/address/data/datasources/address_data_sources.dart';
import 'package:food_delivery/features/address/data/models/address_model.dart';
import 'package:food_delivery/features/address/domain/entities/address.dart';
import 'package:food_delivery/features/address/domain/repositories/address_repository.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: AddressRepository)
class AddressRepositoryImpl implements AddressRepository {
  AddressRepositoryImpl(this._remote, this._local);

  final AddressRemoteDataSource _remote;
  final AddressLocalDataSource _local;

  @override
  Stream<Either<Failure, List<Address>>> watchSaved() =>
      eitherStream(() => _remote.watch().map((list) => list.map((m) => m.toEntity()).toList()));

  @override
  FutureEither<Address> save(Address address) =>
      guard(() async => (await _remote.save(AddressModel.fromEntity(address))).toEntity());

  @override
  FutureEither<Unit> delete(String id) => guard(() async {
    await _remote.delete(id);
    return unit;
  });

  @override
  Address? current() => _local.readCurrent()?.toEntity();

  @override
  Future<void> setCurrent(Address address) => _local.writeCurrent(AddressModel.fromEntity(address));
}

@LazySingleton(as: LocationRepository)
class LocationRepositoryImpl implements LocationRepository {
  LocationRepositoryImpl(this._dataSource);

  final LocationDataSource _dataSource;

  @override
  FutureEither<Coordinates> currentPosition() => guard(_dataSource.currentPosition);

  @override
  FutureEither<String> reverseGeocode(Coordinates point, {String? languageCode}) =>
      guard(() => _dataSource.reverseGeocode(point, languageCode: languageCode));

  @override
  Future<void> openAppSettings() => _dataSource.openAppSettings();

  @override
  Future<void> openLocationSettings() => _dataSource.openLocationSettings();
}
