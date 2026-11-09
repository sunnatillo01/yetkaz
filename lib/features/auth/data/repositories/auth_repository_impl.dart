import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:food_delivery/core/error/exception_mapper.dart';
import 'package:food_delivery/core/notifications/push_notification_service.dart';
import 'package:food_delivery/core/storage/local_data_cleaner.dart';
import 'package:food_delivery/core/storage/token_storage.dart';
import 'package:food_delivery/core/usecase/usecase.dart';
import 'package:food_delivery/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:food_delivery/features/auth/domain/entities/app_user.dart';
import 'package:food_delivery/features/auth/domain/entities/phone_verification.dart';
import 'package:food_delivery/features/auth/domain/repositories/auth_repository.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: AuthRepository)
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._remote, this._tokenStorage, this._cleaner, this._push);

  final AuthRemoteDataSource _remote;
  final TokenStorage _tokenStorage;
  final LocalDataCleaner _cleaner;
  final PushNotificationService _push;

  static AppUser? toEntity(User? user) => user == null
      ? null
      : AppUser(
          uid: user.uid,
          phone: user.phoneNumber ?? '',
          name: user.displayName,
          avatarUrl: user.photoURL,
        );

  Future<void> _storeToken() async {
    final token = await _remote.idToken();
    if (token != null) await _tokenStorage.write(token);
  }

  @override
  Stream<AppUser?> watchSession() => _remote.userChanges().asyncMap((user) async {
    if (user != null) {
      try {
        await _storeToken();
      } on Object catch (_) {
        // Offline: keep the previous token, the interceptor refreshes later.
      }
    }
    return toEntity(user);
  });

  @override
  Future<AppUser?> currentSession() async {
    final user = _remote.currentUser;
    if (user != null) {
      try {
        await _storeToken();
      } on Object catch (_) {}
    }
    return toEntity(user);
  }

  @override
  Stream<PhoneVerification> verifyPhone(String phoneE164, {int? resendToken}) => _remote
      .verifyPhone(phoneE164, resendToken: resendToken)
      .transform(
        StreamTransformer<PhoneVerification, PhoneVerification>.fromHandlers(
          handleError: (error, stack, sink) =>
              sink.add(PhoneVerification.failed(mapExceptionToFailure(error, stack))),
        ),
      );

  @override
  FutureEither<AppUser> signInWithCode({required String verificationId, required String smsCode}) =>
      guard(() async {
        final user = await _remote.signInWithCode(verificationId, smsCode);
        await _storeToken();
        return toEntity(user)!;
      });

  @override
  FutureEither<AppUser> createProfile(String name) => guard(() async {
    final user = await _remote.createProfile(name);
    return toEntity(user)!;
  });

  @override
  FutureEither<Unit> logout() => guard(() async {
    try {
      await _push.unregister();
    } on Object catch (_) {
      // Logging out must work offline too.
    }
    await _remote.signOut();
    await _cleaner.clearUserData();
    return unit;
  });

  @override
  FutureEither<Unit> deleteAccount() => guard(() async {
    await _push.unregister();
    await _remote.deleteAccount();
    await _cleaner.clearUserData();
    return unit;
  });
}
