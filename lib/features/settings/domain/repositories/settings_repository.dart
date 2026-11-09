import 'package:food_delivery/core/usecase/usecase.dart';
import 'package:food_delivery/features/settings/domain/entities/app_settings.dart';
import 'package:fpdart/fpdart.dart';

abstract interface class SettingsRepository {
  AppSettings load();

  Future<void> save(AppSettings settings);

  /// Enables/disables push: stores/deletes the FCM token on the server.
  FutureEither<Unit> setPushEnabled({required bool enabled});

  /// Stores the preferred language on the server (localized pushes).
  FutureEither<Unit> syncLanguage(AppLanguage language);

  Future<AppInfo> appInfo();
}
