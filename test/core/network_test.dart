import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_delivery/core/error/exception_mapper.dart';
import 'package:food_delivery/core/error/exceptions.dart';
import 'package:food_delivery/core/error/failures.dart';
import 'package:food_delivery/core/network/auth_interceptor.dart';
import 'package:food_delivery/core/network/error_interceptor.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/mocks.dart';

/// Answers 401 until the request carries the [validToken].
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.validToken);

  final String validToken;
  final List<String?> seenTokens = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final auth = options.headers['Authorization'] as String?;
    seenTokens.add(auth);
    final ok = auth == 'Bearer $validToken';
    return ResponseBody.fromString(
      jsonEncode(ok ? {'orderId': 'o1'} : {'error': 'token_expired'}),
      ok ? 200 : 401,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('ErrorInterceptor.classify', () {
    DioException err(DioExceptionType type, {int? status, Object? data}) => DioException(
      requestOptions: RequestOptions(),
      type: type,
      response: status == null
          ? null
          : Response<dynamic>(requestOptions: RequestOptions(), statusCode: status, data: data),
    );

    test('maps transport errors', () {
      expect(
        ErrorInterceptor.classify(err(DioExceptionType.connectionTimeout)),
        isA<RequestTimeoutException>(),
      );
      expect(
        ErrorInterceptor.classify(err(DioExceptionType.connectionError)),
        isA<NetworkException>(),
      );
    });

    test('maps HTTP status codes', () {
      expect(
        ErrorInterceptor.classify(err(DioExceptionType.badResponse, status: 401)),
        isA<UnauthorizedException>(),
      );
      expect(
        ErrorInterceptor.classify(err(DioExceptionType.badResponse, status: 404)),
        isA<NotFoundException>(),
      );
      expect(
        ErrorInterceptor.classify(err(DioExceptionType.badResponse, status: 503)),
        isA<ServerException>(),
      );
    });

    test('maps business error codes from the body', () {
      final e = ErrorInterceptor.classify(
        err(DioExceptionType.badResponse, status: 409, data: {'error': 'not_cancellable'}),
      );
      expect(e, isA<BusinessException>());
      expect((e as BusinessException).code, BusinessErrorCode.notCancellable);
    });
  });

  group('mapExceptionToFailure', () {
    test('never leaks technical errors', () {
      expect(mapExceptionToFailure(const NetworkException()), const Failure.network());
      expect(mapExceptionToFailure(const CacheException()), const Failure.cache());
      expect(
        mapExceptionToFailure(const UnauthorizedException()),
        const Failure.auth(AuthErrorCode.sessionExpired),
      );
      expect(mapExceptionToFailure(StateError('boom')), const Failure.unknown());
    });

    test('unwraps the classified error inside DioException', () {
      final dio = DioException(
        requestOptions: RequestOptions(),
        error: const RequestTimeoutException(),
      );
      expect(mapExceptionToFailure(dio), const Failure.timeout());
    });

    test('eitherStream keeps the stream alive and maps errors', () async {
      final values = await eitherStream(
        () => Stream<int>.fromIterable([1]).asyncExpand(
          (v) => Stream.fromFutures([Future.value(v), Future<int>.error(const NetworkException())]),
        ),
      ).toList();
      expect(values.first.isRight(), isTrue);
      expect(values.last.getLeft().toNullable(), const Failure.network());
    });
  });

  group('AuthInterceptor', () {
    late MockTokenStorage storage;
    late MockTokenRefresher refresher;

    setUp(() {
      storage = MockTokenStorage();
      refresher = MockTokenRefresher();
      when(() => storage.write(any())).thenAnswer((_) async {});
    });

    Dio buildDio(_FakeAdapter adapter) {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))..httpClientAdapter = adapter;
      dio.interceptors.add(
        AuthInterceptor(tokenStorage: storage, tokenRefresher: refresher, retryClient: dio),
      );
      return dio;
    }

    test('adds the token to every request', () async {
      when(() => storage.read()).thenAnswer((_) async => 'good');
      final adapter = _FakeAdapter('good');
      final res = await buildDio(adapter).post<Map<String, dynamic>>('/createOrder');
      expect(res.data!['orderId'], 'o1');
      expect(adapter.seenTokens, ['Bearer good']);
      verifyNever(() => refresher.refreshToken());
    });

    test('on 401 refreshes the token once and retries the request', () async {
      var stored = 'expired';
      when(() => storage.read()).thenAnswer((_) async => stored);
      when(() => storage.write(any())).thenAnswer((inv) async {
        stored = inv.positionalArguments.first as String;
      });
      when(() => refresher.refreshToken()).thenAnswer((_) async => 'fresh');
      final adapter = _FakeAdapter('fresh');

      final res = await buildDio(adapter).post<Map<String, dynamic>>('/createOrder');

      expect(res.statusCode, 200);
      expect(adapter.seenTokens, ['Bearer expired', 'Bearer fresh']);
      verify(() => refresher.refreshToken()).called(1);
      verify(() => storage.write('fresh')).called(1);
    });

    test('gives up when the token cannot be refreshed', () async {
      when(() => storage.read()).thenAnswer((_) async => 'expired');
      when(() => refresher.refreshToken()).thenAnswer((_) async => null);
      final adapter = _FakeAdapter('fresh');

      await expectLater(buildDio(adapter).post<void>('/createOrder'), throwsA(isA<DioException>()));
      expect(adapter.seenTokens, hasLength(1));
    });
  });
}
