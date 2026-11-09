import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:food_delivery/core/error/error_reporter.dart';
import 'package:food_delivery/core/error/exceptions.dart';
import 'package:food_delivery/core/error/failures.dart';
import 'package:fpdart/fpdart.dart';

/// Converts any thrown object into a user-presentable [Failure].
Failure mapExceptionToFailure(Object error, [StackTrace? stackTrace]) {
  final source = error is DioException && error.error is AppException ? error.error! : error;

  switch (source) {
    case NetworkException():
      return const Failure.network();
    case RequestTimeoutException():
      return const Failure.timeout();
    case UnauthorizedException():
      return const Failure.auth(AuthErrorCode.sessionExpired);
    case NotFoundException():
      return const Failure.notFound();
    case ServerException(:final code):
      return Failure.server(code: code);
    case CacheException():
      return const Failure.cache();
    case BusinessException(:final code):
      return Failure.business(code);
    case AuthException(:final code):
      return Failure.auth(code);
    case LocationException(:final code):
      return Failure.location(code);
    case fb.FirebaseAuthException(:final code):
      return Failure.auth(_authCode(code));
    case FirebaseException(:final code):
      return _firebaseFailure(code);
    case DioException():
      return const Failure.network();
  }
  ErrorReporter.report(error, stackTrace);
  return const Failure.unknown();
}

/// Runs [body] and converts thrown errors into `Left(Failure)`.
Future<Either<Failure, T>> guard<T>(Future<T> Function() body) async {
  try {
    return Right(await body());
  } on Object catch (e, s) {
    return Left(mapExceptionToFailure(e, s));
  }
}

/// Converts a data stream into a stream of `Either`, mapping errors to
/// `Left(Failure)` without closing the stream.
Stream<Either<Failure, T>> eitherStream<T>(Stream<T> Function() source) {
  late final Stream<T> stream;
  try {
    stream = source();
  } on Object catch (e, s) {
    return Stream.value(Left(mapExceptionToFailure(e, s)));
  }
  return stream.transform(
    StreamTransformer<T, Either<Failure, T>>.fromHandlers(
      handleData: (data, sink) => sink.add(Right(data)),
      handleError: (error, stack, sink) => sink.add(Left(mapExceptionToFailure(error, stack))),
    ),
  );
}

AuthErrorCode _authCode(String code) => switch (code) {
  'invalid-verification-code' => AuthErrorCode.invalidCode,
  'session-expired' || 'code-expired' => AuthErrorCode.codeExpired,
  'too-many-requests' || 'quota-exceeded' => AuthErrorCode.tooManyRequests,
  'invalid-phone-number' => AuthErrorCode.invalidPhone,
  'user-token-expired' || 'requires-recent-login' => AuthErrorCode.sessionExpired,
  'network-request-failed' => AuthErrorCode.unknown,
  _ => AuthErrorCode.unknown,
};

Failure _firebaseFailure(String code) => switch (code) {
  'unavailable' => const Failure.network(),
  'deadline-exceeded' => const Failure.timeout(),
  'not-found' => const Failure.notFound(),
  'permission-denied' => const Failure.permission(),
  'unauthenticated' => const Failure.auth(AuthErrorCode.sessionExpired),
  _ => Failure.server(code: code),
};
