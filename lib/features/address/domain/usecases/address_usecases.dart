import 'package:food_delivery/core/entities/coordinates.dart';
import 'package:food_delivery/core/error/failures.dart';
import 'package:food_delivery/core/usecase/usecase.dart';
import 'package:food_delivery/features/address/domain/entities/address.dart';
import 'package:food_delivery/features/address/domain/repositories/address_repository.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

@injectable
class WatchSavedAddresses {
  const WatchSavedAddresses(this._repository);
  final AddressRepository _repository;

  Stream<Either<Failure, List<Address>>> call() => _repository.watchSaved();
}

/// Saves the address and makes it the current delivery address.
@injectable
class SaveAddress implements UseCase<Address, Address> {
  const SaveAddress(this._repository);
  final AddressRepository _repository;

  @override
  FutureEither<Address> call(Address address) async {
    final result = await _repository.save(address);
    return result.fold(Left.new, (saved) async {
      final current = _repository.current();
      if (current == null || current.id == saved.id || address.id == null) {
        await _repository.setCurrent(saved);
      }
      return Right(saved);
    });
  }
}

@injectable
class DeleteAddress implements UseCase<Unit, String> {
  const DeleteAddress(this._repository);
  final AddressRepository _repository;

  @override
  FutureEither<Unit> call(String id) => _repository.delete(id);
}

@injectable
class GetCurrentAddress {
  const GetCurrentAddress(this._repository);
  final AddressRepository _repository;

  Address? call() => _repository.current();
}

@injectable
class SelectAddress {
  const SelectAddress(this._repository);
  final AddressRepository _repository;

  Future<void> call(Address address) => _repository.setCurrent(address);
}

@injectable
class GetMyLocation implements UseCase<Coordinates, NoParams> {
  const GetMyLocation(this._repository);
  final LocationRepository _repository;

  @override
  FutureEither<Coordinates> call(NoParams params) => _repository.currentPosition();
}

@injectable
class ResolveAddress {
  const ResolveAddress(this._repository);
  final LocationRepository _repository;

  FutureEither<String> call(Coordinates point, {String? languageCode}) =>
      _repository.reverseGeocode(point, languageCode: languageCode);
}
