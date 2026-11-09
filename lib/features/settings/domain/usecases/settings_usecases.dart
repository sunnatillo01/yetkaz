import 'package:food_delivery/core/usecase/usecase.dart';
import 'package:food_delivery/features/settings/domain/entities/app_settings.dart';
import 'package:food_delivery/features/settings/domain/repositories/settings_repository.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

@injectable
class GetSettings {
  const GetSettings(this._repository);
  final SettingsRepository _repository;

  AppSettings call() => _repository.load();
}

@injectable
class ChangeLanguage implements UseCase<AppSettings, AppLanguage> {
  const ChangeLanguage(this._repository);
  final SettingsRepository _repository;

  /// Saves locally first (instant UI switch) then syncs to the server
  /// best-effort; a server failure never blocks the language change.
  @override
  FutureEither<AppSettings> call(AppLanguage language) async {
    final updated = _repository.load().copyWith(language: language);
    await _repository.save(updated);
    await _repository.syncLanguage(language);
    return Right(updated);
  }
}

@injectable
class ChangeThemeMode implements UseCase<AppSettings, AppThemeMode> {
  const ChangeThemeMode(this._repository);
  final SettingsRepository _repository;

  @override
  FutureEither<AppSettings> call(AppThemeMode mode) async {
    final updated = _repository.load().copyWith(themeMode: mode);
    await _repository.save(updated);
    return Right(updated);
  }
}

@injectable
class TogglePushNotifications implements UseCase<AppSettings, bool> {
  const TogglePushNotifications(this._repository);
  final SettingsRepository _repository;

  @override
  FutureEither<AppSettings> call(bool enabled) async {
    final result = await _repository.setPushEnabled(enabled: enabled);
    return result.fold(Left.new, (_) async {
      final updated = _repository.load().copyWith(notificationsEnabled: enabled);
      await _repository.save(updated);
      return Right(updated);
    });
  }
}

@injectable
class CompleteOnboarding {
  const CompleteOnboarding(this._repository);
  final SettingsRepository _repository;

  Future<void> call() => _repository.save(_repository.load().copyWith(onboardingSeen: true));
}

@injectable
class GetAppInfo {
  const GetAppInfo(this._repository);
  final SettingsRepository _repository;

  Future<AppInfo> call() => _repository.appInfo();
}
