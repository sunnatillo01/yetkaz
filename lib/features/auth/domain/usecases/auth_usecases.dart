import 'package:food_delivery/core/error/failures.dart';
import 'package:food_delivery/core/usecase/usecase.dart';
import 'package:food_delivery/core/utils/validators.dart';
import 'package:food_delivery/features/auth/domain/entities/app_user.dart';
import 'package:food_delivery/features/auth/domain/entities/phone_verification.dart';
import 'package:food_delivery/features/auth/domain/repositories/auth_repository.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

@injectable
class SendOtp {
  const SendOtp(this._repository);
  final AuthRepository _repository;

  Stream<PhoneVerification> call(String phoneE164, {int? resendToken}) {
    final local = phoneE164.replaceFirst('+998', '');
    if (!Validators.isValidPhone(local)) {
      return Stream.value(const PhoneVerification.failed(Failure.auth(AuthErrorCode.invalidPhone)));
    }
    return _repository.verifyPhone(phoneE164, resendToken: resendToken);
  }
}

class VerifyOtpParams {
  const VerifyOtpParams({required this.verificationId, required this.code});
  final String verificationId;
  final String code;
}

@injectable
class VerifyOtp implements UseCase<AppUser, VerifyOtpParams> {
  const VerifyOtp(this._repository);
  final AuthRepository _repository;

  @override
  FutureEither<AppUser> call(VerifyOtpParams params) async {
    if (!Validators.isValidOtp(params.code)) {
      return const Left(Failure.auth(AuthErrorCode.invalidCode));
    }
    return _repository.signInWithCode(verificationId: params.verificationId, smsCode: params.code);
  }
}

@injectable
class CreateProfile implements UseCase<AppUser, String> {
  const CreateProfile(this._repository);
  final AuthRepository _repository;

  @override
  FutureEither<AppUser> call(String name) async {
    if (!Validators.isValidName(name)) return const Left(Failure.unknown());
    return _repository.createProfile(name.trim());
  }
}

@injectable
class WatchSession {
  const WatchSession(this._repository);
  final AuthRepository _repository;

  Stream<AppUser?> call() => _repository.watchSession();
}

@injectable
class GetCurrentSession {
  const GetCurrentSession(this._repository);
  final AuthRepository _repository;

  Future<AppUser?> call() => _repository.currentSession();
}

@injectable
class Logout implements UseCase<Unit, NoParams> {
  const Logout(this._repository);
  final AuthRepository _repository;

  @override
  FutureEither<Unit> call(NoParams params) => _repository.logout();
}

@injectable
class DeleteAccount implements UseCase<Unit, NoParams> {
  const DeleteAccount(this._repository);
  final AuthRepository _repository;

  @override
  FutureEither<Unit> call(NoParams params) => _repository.deleteAccount();
}
