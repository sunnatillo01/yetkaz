import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_delivery/core/error/failures.dart';
import 'package:food_delivery/features/onboarding/presentation/bloc/splash_cubit.dart';
import 'package:food_delivery/features/settings/domain/entities/app_settings.dart';
import 'package:food_delivery/features/settings/domain/usecases/settings_usecases.dart';
import 'package:food_delivery/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/fixtures.dart';
import '../../helpers/mocks.dart';

void main() {
  setUpAll(() {
    registerFallbacks();
    registerFallbackValue(const AppSettings());
    registerFallbackValue(AppLanguage.uz);
    registerFallbackValue(AppThemeMode.system);
  });

  group('settings use cases', () {
    late MockSettingsRepository repo;
    setUp(() {
      repo = MockSettingsRepository();
      when(() => repo.load()).thenReturn(const AppSettings());
      when(() => repo.save(any())).thenAnswer((_) async {});
      when(() => repo.syncLanguage(any())).thenAnswer((_) async => const Right(unit));
    });

    test('ChangeLanguage saves locally and syncs to the server', () async {
      final result = await ChangeLanguage(repo)(AppLanguage.ru);
      expect(result.getRight().toNullable()!.language, AppLanguage.ru);
      verify(() => repo.save(const AppSettings(language: AppLanguage.ru))).called(1);
      verify(() => repo.syncLanguage(AppLanguage.ru)).called(1);
    });

    test('ChangeLanguage succeeds even when server sync fails', () async {
      when(() => repo.syncLanguage(any())).thenAnswer((_) async => const Left(Failure.network()));
      expect((await ChangeLanguage(repo)(AppLanguage.en)).isRight(), isTrue);
    });

    test('ChangeThemeMode persists the mode', () async {
      await ChangeThemeMode(repo)(AppThemeMode.dark);
      verify(() => repo.save(const AppSettings(themeMode: AppThemeMode.dark))).called(1);
    });

    test('TogglePushNotifications saves only after the server succeeded', () async {
      when(() => repo.setPushEnabled(enabled: false))
          .thenAnswer((_) async => const Left(Failure.network()));
      expect((await TogglePushNotifications(repo)(false)).isLeft(), isTrue);
      verifyNever(() => repo.save(any()));

      when(() => repo.setPushEnabled(enabled: false)).thenAnswer((_) async => const Right(unit));
      final ok = await TogglePushNotifications(repo)(false);
      expect(ok.getRight().toNullable()!.notificationsEnabled, isFalse);
    });

    test('CompleteOnboarding sets the flag', () async {
      await CompleteOnboarding(repo)();
      verify(() => repo.save(const AppSettings(onboardingSeen: true))).called(1);
    });

    test('AppLanguage.fromCode', () {
      expect(AppLanguage.fromCode('ru'), AppLanguage.ru);
      expect(AppLanguage.fromCode('de'), isNull);
      expect(AppLanguage.fromCode(null), isNull);
    });
  });

  group('SettingsCubit', () {
    late MockGetSettings get;
    late MockChangeLanguage language;
    late MockChangeThemeMode theme;
    late MockTogglePushNotifications push;
    late MockGetAppInfo info;
    late MockCompleteOnboarding onboarding;

    setUp(() {
      get = MockGetSettings();
      language = MockChangeLanguage();
      theme = MockChangeThemeMode();
      push = MockTogglePushNotifications();
      info = MockGetAppInfo();
      onboarding = MockCompleteOnboarding();
      when(() => get()).thenReturn(const AppSettings());
      when(() => language(any())).thenAnswer((_) async => const Right(AppSettings()));
      when(() => theme(any())).thenAnswer((_) async => const Right(AppSettings()));
    });

    SettingsCubit build() => SettingsCubit(get, language, theme, push, info, onboarding);

    blocTest<SettingsCubit, SettingsState>(
      'language switches immediately (no restart)',
      build: build,
      act: (c) => c.setLanguage(AppLanguage.en),
      expect: () => [const SettingsState(settings: AppSettings(language: AppLanguage.en))],
    );

    blocTest<SettingsCubit, SettingsState>(
      'theme switches immediately',
      build: build,
      act: (c) => c.setThemeMode(AppThemeMode.dark),
      expect: () => [const SettingsState(settings: AppSettings(themeMode: AppThemeMode.dark))],
    );

    blocTest<SettingsCubit, SettingsState>(
      'push toggle failure is reported and the switch stays',
      build: () {
        when(() => push(any())).thenAnswer((_) async => const Left(Failure.network()));
        return build();
      },
      act: (c) => c.setPushEnabled(enabled: false),
      expect: () => [
        const SettingsState(settings: AppSettings(), isUpdatingPush: true),
        const SettingsState(settings: AppSettings(), failure: Failure.network()),
      ],
    );

    blocTest<SettingsCubit, SettingsState>(
      'loads version and flavor',
      build: () {
        when(() => info()).thenAnswer(
          (_) async =>
              const AppInfo(version: '1.0.0', buildNumber: '1', flavor: 'dev', showFlavor: true),
        );
        return build();
      },
      act: (c) => c.loadInfo(),
      verify: (c) => expect(c.state.info!.flavor, 'dev'),
    );
  });

  group('SplashCubit', () {
    late MockGetSettings settings;
    late MockGetCurrentSession session;

    setUp(() {
      settings = MockGetSettings();
      session = MockGetCurrentSession();
    });

    blocTest<SplashCubit, SplashState>(
      'first launch goes to onboarding',
      build: () {
        when(() => settings()).thenReturn(const AppSettings());
        when(() => session()).thenAnswer((_) async => null);
        return SplashCubit(settings, session);
      },
      act: (c) => c.start(),
      wait: SplashCubit.minDisplay,
      expect: () => [
        const SplashState.loading(),
        const SplashState.success(SplashDestination.onboarding),
      ],
    );

    blocTest<SplashCubit, SplashState>(
      'no token → login',
      build: () {
        when(() => settings())
            .thenReturn(const AppSettings(onboardingSeen: true, language: AppLanguage.uz));
        when(() => session()).thenAnswer((_) async => null);
        return SplashCubit(settings, session);
      },
      act: (c) => c.start(),
      wait: SplashCubit.minDisplay,
      expect: () => [
        const SplashState.loading(),
        const SplashState.success(SplashDestination.login),
      ],
    );

    blocTest<SplashCubit, SplashState>(
      'signed in → home; new user → name',
      build: () {
        when(() => settings())
            .thenReturn(const AppSettings(onboardingSeen: true, language: AppLanguage.uz));
        when(() => session()).thenAnswer((_) async => tUser);
        return SplashCubit(settings, session);
      },
      act: (c) => c.start(),
      wait: SplashCubit.minDisplay,
      expect: () => [
        const SplashState.loading(),
        const SplashState.success(SplashDestination.home),
      ],
    );

    blocTest<SplashCubit, SplashState>(
      'new user without name → profile',
      build: () {
        when(() => settings())
            .thenReturn(const AppSettings(onboardingSeen: true, language: AppLanguage.uz));
        when(() => session()).thenAnswer((_) async => tNewUser);
        return SplashCubit(settings, session);
      },
      act: (c) => c.start(),
      wait: SplashCubit.minDisplay,
      expect: () => [
        const SplashState.loading(),
        const SplashState.success(SplashDestination.profile),
      ],
    );
  });
}
