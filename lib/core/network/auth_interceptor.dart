import 'package:dio/dio.dart';
import 'package:food_delivery/core/network/token_refresher.dart';
import 'package:food_delivery/core/storage/token_storage.dart';

/// Adds `Authorization: Bearer <token>` to every request. On `401` it
/// refreshes the token once and transparently retries the original request.
///
/// [QueuedInterceptor] serialises concurrent requests, so parallel 401s
/// trigger only one refresh.
class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor({
    required this._tokenStorage,
    required this._tokenRefresher,
    required this._retryClient,
  });

  final TokenStorage _tokenStorage;
  final TokenRefresher _tokenRefresher;
  final Dio _retryClient;

  static const _retriedKey = 'auth_retried';

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await _tokenStorage.read();
    if (token != null) options.headers['Authorization'] = 'Bearer $token';
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final alreadyRetried = err.requestOptions.extra[_retriedKey] == true;
    if (err.response?.statusCode != 401 || alreadyRetried) {
      return handler.next(err);
    }
    try {
      final newToken = await _tokenRefresher.refreshToken();
      if (newToken == null) return handler.next(err);
      await _tokenStorage.write(newToken);

      final options = err.requestOptions
        ..headers['Authorization'] = 'Bearer $newToken'
        ..extra[_retriedKey] = true;
      final response = await _retryClient.fetch<dynamic>(options);
      handler.resolve(response);
    } on DioException catch (e) {
      handler.next(e);
    }
  }
}
