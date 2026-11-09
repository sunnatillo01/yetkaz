import 'package:dio/dio.dart';
import 'package:food_delivery/core/error/exceptions.dart';
import 'package:food_delivery/core/error/failures.dart';

/// Classifies every [DioException] into a typed [AppException] stored in
/// `DioException.error`: timeout, no internet, 401, 404, 5xx, business codes.
class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    handler.next(err.copyWith(error: classify(err)));
  }

  static AppException classify(DioException err) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const RequestTimeoutException();
      case DioExceptionType.connectionError:
        return const NetworkException();
      case DioExceptionType.badResponse:
        return _fromResponse(err.response);
      case DioExceptionType.badCertificate:
      case DioExceptionType.cancel:
      case DioExceptionType.unknown:
        return const ServerException();
    }
  }

  static AppException _fromResponse(Response<dynamic>? response) {
    final status = response?.statusCode ?? 0;
    final data = response?.data;
    final code = data is Map ? data['error'] as String? : null;

    final business = switch (code) {
      'restaurant_closed' => BusinessErrorCode.restaurantClosed,
      'below_min_order' => BusinessErrorCode.belowMinOrder,
      'not_cancellable' => BusinessErrorCode.notCancellable,
      _ => null,
    };
    if (business != null) return BusinessException(business);

    return switch (status) {
      401 => const UnauthorizedException(),
      404 => const NotFoundException(),
      >= 500 => ServerException(statusCode: status, code: code),
      _ => ServerException(statusCode: status, code: code),
    };
  }
}
