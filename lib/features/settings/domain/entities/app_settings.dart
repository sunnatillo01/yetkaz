import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_settings.freezed.dart';

enum AppThemeMode { system, light, dark }

enum AppLanguage {
  uz,
  ru,
  en;

  static AppLanguage? fromCode(String? code) =>
      AppLanguage.values.where((l) => l.name == code).firstOrNull;
}

@freezed
abstract class AppSettings with _$AppSettings {
  const factory AppSettings({
    AppLanguage? language,
    @Default(AppThemeMode.system) AppThemeMode themeMode,
    @Default(true) bool notificationsEnabled,
    @Default(false) bool onboardingSeen,
  }) = _AppSettings;
}

@freezed
abstract class AppInfo with _$AppInfo {
  const factory AppInfo({
    required String version,
    required String buildNumber,
    required String flavor,
    required bool showFlavor,
  }) = _AppInfo;
}
