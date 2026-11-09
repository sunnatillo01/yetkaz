import 'package:food_delivery/core/storage/hive_boxes.dart';
import 'package:food_delivery/features/settings/domain/entities/app_settings.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class SettingsLocalDataSource {
  SettingsLocalDataSource(@Named(HiveBoxes.settings) this._box);

  final Box<dynamic> _box;

  static const _language = 'language';
  static const _theme = 'theme';
  static const _notifications = 'notifications';
  static const _onboarding = 'onboarding_seen';

  AppSettings read() => AppSettings(
    language: AppLanguage.fromCode(_box.get(_language) as String?),
    themeMode: AppThemeMode.values.firstWhere(
      (m) => m.name == _box.get(_theme),
      orElse: () => AppThemeMode.system,
    ),
    notificationsEnabled: _box.get(_notifications, defaultValue: true) as bool,
    onboardingSeen: _box.get(_onboarding, defaultValue: false) as bool,
  );

  Future<void> write(AppSettings s) => _box.putAll({
    _language: s.language?.name,
    _theme: s.themeMode.name,
    _notifications: s.notificationsEnabled,
    _onboarding: s.onboardingSeen,
  });
}
