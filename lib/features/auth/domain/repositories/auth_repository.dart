import 'package:food_delivery/core/usecase/usecase.dart';
import 'package:food_delivery/features/auth/domain/entities/app_user.dart';
import 'package:food_delivery/features/auth/domain/entities/phone_verification.dart';
import 'package:fpdart/fpdart.dart';

abstract interface class AuthRepository {
  /// Emits the signed-in user (or `null`) whenever auth/profile changes.
  Stream<AppUser?> watchSession();

  /// Current session; also refreshes the stored token.
  Future<AppUser?> currentSession();

  /// [phoneE164] like `+998901234567`.
  Stream<PhoneVerification> verifyPhone(String phoneE164, {int? resendToken});

  FutureEither<AppUser> signInWithCode({required String verificationId, required String smsCode});

  FutureEither<AppUser> createProfile(String name);

  FutureEither<Unit> logout();

  FutureEither<Unit> deleteAccount();
}
