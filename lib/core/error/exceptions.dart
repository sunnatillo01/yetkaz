import 'package:food_delivery/core/error/failures.dart';

/// Exceptions thrown inside the data layer. Repositories convert them into
/// [Failure]s via `mapExceptionToFailure`.
sealed class AppException implements Exception {
  const AppException();
}

class NetworkException extends AppException {
  const NetworkException();
}

class RequestTimeoutException extends AppException {
  const RequestTimeoutException();
}

class UnauthorizedException extends AppException {
  const UnauthorizedException();
}

class NotFoundException extends AppException {
  const NotFoundException();
}

class ServerException extends AppException {
  const ServerException({this.statusCode, this.code});
  final int? statusCode;
  final String? code;
}

class CacheException extends AppException {
  const CacheException();
}

class BusinessException extends AppException {
  const BusinessException(this.code);
  final BusinessErrorCode code;
}

class AuthException extends AppException {
  const AuthException(this.code);
  final AuthErrorCode code;
}

class LocationException extends AppException {
  const LocationException(this.code);
  final LocationErrorCode code;
}
