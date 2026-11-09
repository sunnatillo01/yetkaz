import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_delivery/core/error/failures.dart';
import 'package:food_delivery/core/usecase/usecase.dart';
import 'package:food_delivery/features/auth/domain/entities/phone_verification.dart';
import 'package:food_delivery/features/auth/domain/usecases/auth_usecases.dart';
import 'package:food_delivery/features/auth/presentation/bloc/name_cubit.dart';
import 'package:food_delivery/features/auth/presentation/bloc/otp_cubit.dart';
import 'package:food_delivery/features/auth/presentation/bloc/phone_cubit.dart';
import 'package:food_delivery/features/auth/presentation/bloc/session_cubit.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/fixtures.dart';
import '../../helpers/mocks.dart';

void main() {
  setUpAll(registerFallbacks);

  group('use cases', () {
    late MockAuthRepository repo;
    setUp(() => repo = MockAuthRepository());

    test('SendOtp rejects an invalid number without calling Firebase', () async {
      final events = await SendOtp(repo)('+998121234567').toList();
      expect(events.single, isA<PhoneVerificationFailed>());
      verifyNever(() => repo.verifyPhone(any()));
    });

    test('SendOtp forwards a valid number', () async {
      when(() => repo.verifyPhone(any(), resendToken: any(named: 'resendToken')))
          .thenAnswer((_) => Stream.value(const PhoneVerification.codeSent(verificationId: 'v')));
      final events = await SendOtp(repo)('+998901234567').toList();
      expect(events.single, isA<PhoneCodeSent>());
    });

    test('VerifyOtp validates the code format', () async {
      final result = await VerifyOtp(repo)(const VerifyOtpParams(verificationId: 'v', code: '12'));
      expect(result, const Left<Failure, Never>(Failure.auth(AuthErrorCode.invalidCode)));
      verifyNever(
        () => repo.signInWithCode(
          verificationId: any(named: 'verificationId'),
          smsCode: any(named: 'smsCode'),
        ),
      );
    });

    test('VerifyOtp signs in with a 6-digit code', () async {
      when(() => repo.signInWithCode(verificationId: 'v', smsCode: '123456'))
          .thenAnswer((_) async => const Right(tUser));
      final result = await VerifyOtp(repo)(
        const VerifyOtpParams(verificationId: 'v', code: '123456'),
      );
      expect(result, const Right<Failure, dynamic>(tUser));
    });

    test('CreateProfile trims and validates the name', () async {
      when(() => repo.createProfile('Ali')).thenAnswer((_) async => const Right(tUser));
      expect((await CreateProfile(repo)('  Ali  ')).isRight(), isTrue);
      expect((await CreateProfile(repo)('A')).isLeft(), isTrue);
      verify(() => repo.createProfile('Ali')).called(1);
    });

    test('Logout delegates to the repository', () async {
      when(() => repo.logout()).thenAnswer((_) async => const Right(unit));
      expect(await Logout(repo)(const NoParams()), const Right<Failure, Unit>(unit));
    });
  });

  group('SessionCubit', () {
    late MockWatchSession watch;
    late MockGetCurrentSession current;
    late StreamController<dynamic> changes;

    setUp(() {
      watch = MockWatchSession();
      current = MockGetCurrentSession();
      changes = StreamController.broadcast();
      when(() => watch()).thenAnswer((_) => changes.stream.cast());
    });

    blocTest<SessionCubit, SessionState>(
      'resolves an authenticated user with a profile',
      build: () {
        when(() => current()).thenAnswer((_) async => tUser);
        return SessionCubit(watch, current);
      },
      act: (c) => c.start(),
      expect: () => [const SessionState.authenticated(tUser)],
    );

    blocTest<SessionCubit, SessionState>(
      'requires the profile for a new user, then reacts to logout',
      build: () {
        when(() => current()).thenAnswer((_) async => tNewUser);
        return SessionCubit(watch, current);
      },
      act: (c) async {
        await c.start();
        changes.add(null);
      },
      expect: () => [
        const SessionState.profileRequired(tNewUser),
        const SessionState.unauthenticated(),
      ],
    );

    blocTest<SessionCubit, SessionState>(
      'is unauthenticated without a user',
      build: () {
        when(() => current()).thenAnswer((_) async => null);
        return SessionCubit(watch, current);
      },
      act: (c) => c.start(),
      expect: () => [const SessionState.unauthenticated()],
      verify: (c) => expect(c.user, isNull),
    );
  });

  group('PhoneCubit', () {
    late MockSendOtp sendOtp;
    setUp(() => sendOtp = MockSendOtp());

    blocTest<PhoneCubit, PhoneState>(
      'emits success with OTP args when the code is sent',
      build: () {
        when(() => sendOtp(any())).thenAnswer(
          (_) =>
              Stream.value(const PhoneVerification.codeSent(verificationId: 'vid', resendToken: 7)),
        );
        return PhoneCubit(sendOtp);
      },
      act: (c) => c.submit('90 123 45 67'),
      expect: () => [
        const PhoneState.loading(),
        const PhoneState.success(
          OtpArgs(phone: '+998901234567', verificationId: 'vid', resendToken: 7),
        ),
      ],
    );

    blocTest<PhoneCubit, PhoneState>(
      'fails fast on an invalid number',
      build: () => PhoneCubit(sendOtp),
      act: (c) => c.submit('12'),
      expect: () => [const PhoneState.failure(Failure.auth(AuthErrorCode.invalidPhone))],
    );

    blocTest<PhoneCubit, PhoneState>(
      'emits failure from Firebase',
      build: () {
        when(() => sendOtp(any())).thenAnswer(
          (_) => Stream.value(
            const PhoneVerification.failed(Failure.auth(AuthErrorCode.tooManyRequests)),
          ),
        );
        return PhoneCubit(sendOtp);
      },
      act: (c) => c.submit('901234567'),
      expect: () => [
        const PhoneState.loading(),
        const PhoneState.failure(Failure.auth(AuthErrorCode.tooManyRequests)),
      ],
    );
  });

  group('OtpCubit', () {
    late MockVerifyOtp verifyOtp;
    late MockSendOtp sendOtp;
    const args = OtpArgs(phone: '+998901234567', verificationId: 'v1', resendToken: 1);

    setUp(() {
      verifyOtp = MockVerifyOtp();
      sendOtp = MockSendOtp();
    });

    blocTest<OtpCubit, OtpState>(
      'signs in with a correct code',
      build: () {
        when(() => verifyOtp(any())).thenAnswer((_) async => const Right(tUser));
        return OtpCubit(verifyOtp, sendOtp)..init(args);
      },
      act: (c) => c.verify('123456'),
      expect: () => [const OtpState.loading(), const OtpState.success(tUser)],
    );

    blocTest<OtpCubit, OtpState>(
      'shows wrong-code failure',
      build: () {
        when(() => verifyOtp(any()))
            .thenAnswer((_) async => const Left(Failure.auth(AuthErrorCode.invalidCode)));
        return OtpCubit(verifyOtp, sendOtp)..init(args);
      },
      act: (c) => c.verify('000000'),
      expect: () => [
        const OtpState.loading(),
        const OtpState.failure(Failure.auth(AuthErrorCode.invalidCode)),
      ],
    );

    blocTest<OtpCubit, OtpState>(
      'resend replaces the verification id',
      build: () {
        when(() => sendOtp(any(), resendToken: 1)).thenAnswer(
          (_) =>
              Stream.value(const PhoneVerification.codeSent(verificationId: 'v2', resendToken: 2)),
        );
        return OtpCubit(verifyOtp, sendOtp)..init(args);
      },
      act: (c) => c.resend(),
      wait: Duration.zero,
      expect: () => [const OtpState.initial()],
      verify: (c) {
        expect(c.args.verificationId, 'v2');
        expect(c.args.resendToken, 2);
      },
    );
  });

  group('ResendTimerCubit', () {
    blocTest<ResendTimerCubit, int>(
      'counts down to zero',
      build: ResendTimerCubit.new,
      act: (c) => c.start(2),
      wait: const Duration(milliseconds: 2100),
      expect: () => [2, 1, 0],
      verify: (c) => expect(c.canResend, isTrue),
    );
  });

  group('NameCubit', () {
    late MockCreateProfile createProfile;
    setUp(() => createProfile = MockCreateProfile());

    blocTest<NameCubit, NameState>(
      'creates the profile',
      build: () {
        when(() => createProfile(any())).thenAnswer((_) async => const Right(tUser));
        return NameCubit(createProfile);
      },
      act: (c) => c.submit('Ali'),
      expect: () => [const NameState.loading(), const NameState.success(tUser)],
    );

    blocTest<NameCubit, NameState>(
      'emits failure when saving fails',
      build: () {
        when(() => createProfile(any())).thenAnswer((_) async => const Left(Failure.network()));
        return NameCubit(createProfile);
      },
      act: (c) => c.submit('Ali'),
      expect: () => [const NameState.loading(), const NameState.failure(Failure.network())],
    );

    blocTest<NameCubit, NameState>(
      'ignores double submit while loading',
      build: () {
        when(() => createProfile(any())).thenAnswer((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return const Right(tUser);
        });
        return NameCubit(createProfile);
      },
      act: (c) {
        c
          ..submit('Ali')
          ..submit('Ali');
      },
      wait: const Duration(milliseconds: 50),
      expect: () => [const NameState.loading(), const NameState.success(tUser)],
      verify: (_) => verify(() => createProfile(any())).called(1),
    );
  });
}
