import 'package:food_delivery/core/error/exception_mapper.dart';
import 'package:food_delivery/core/usecase/usecase.dart';
import 'package:food_delivery/features/profile/data/datasources/profile_remote_data_source.dart';
import 'package:food_delivery/features/profile/domain/repositories/profile_repository.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: ProfileRepository)
class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl(this._remote);

  final ProfileRemoteDataSource _remote;

  @override
  FutureEither<String?> changeAvatar(AvatarSource source) =>
      guard(() => _remote.changeAvatar(source));
}
