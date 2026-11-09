import 'package:freezed_annotation/freezed_annotation.dart';

part 'failures.freezed.dart';

enum AuthErrorCode {
  invalidCode,
  codeExpired,
  tooManyRequests,
  invalidPhone,
  sessionExpired,
  unknown,
}

enum BusinessErrorCode { restaurantClosed, belowMinOrder, notCancellable }

enum LocationErrorCode { serviceDisabled, denied, deniedForever }

/// Domain-level error. Data layer converts every exception into one of these,
/// so presentation never sees technical messages.
@freezed
sealed class Failure with _$Failure {
  const factory Failure.network() = NetworkFailure;
  const factory Failure.timeout() = TimeoutFailure;
  const factory Failure.server({String? code}) = ServerFailure;
  const factory Failure.notFound() = NotFoundFailure;
  const factory Failure.cache() = CacheFailure;
  const factory Failure.auth(AuthErrorCode code) = AuthFailure;
  const factory Failure.permission() = PermissionFailure;
  const factory Failure.business(BusinessErrorCode code) = BusinessFailure;
  const factory Failure.location(LocationErrorCode code) = LocationFailure;
  const factory Failure.unknown() = UnknownFailure;
}
