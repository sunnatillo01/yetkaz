import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:food_delivery/core/error/failures.dart';
import 'package:food_delivery/features/settings/domain/entities/app_settings.dart';
import 'package:food_delivery/features/settings/domain/usecases/settings_usecases.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'settings_cubit.freezed.dart';

@freezed
abstract class SettingsState with _$SettingsState {
  const factory SettingsState({
    required AppSettings settings,
    AppInfo? info,
    @Default(false) bool isUpdatingPush,
    Failure? failure,
  }) = _SettingsState;
}

/// App-wide preferences: language and theme switch instantly, without
/// restarting, because `MaterialApp` rebuilds from this state.
@lazySingleton
class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit(
    GetSettings getSettings,
    this._changeLanguage,
    this._changeTheme,
    this._togglePush,
    this._getAppInfo,
    this._completeOnboarding,
  ) : super(SettingsState(settings: getSettings()));

  final ChangeLanguage _changeLanguage;
  final ChangeThemeMode _changeTheme;
  final TogglePushNotifications _togglePush;
  final GetAppInfo _getAppInfo;
  final CompleteOnboarding _completeOnboarding;

  Future<void> loadInfo() async {
    final info = await _getAppInfo();
    if (!isClosed) emit(state.copyWith(info: info));
  }

  Future<void> setLanguage(AppLanguage language) async {
    // Optimistic: switch immediately, persist in the background.
    emit(state.copyWith(settings: state.settings.copyWith(language: language)));
    await _changeLanguage(language);
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    emit(state.copyWith(settings: state.settings.copyWith(themeMode: mode)));
    await _changeTheme(mode);
  }

  Future<void> setPushEnabled({required bool enabled}) async {
    emit(state.copyWith(isUpdatingPush: true, failure: null));
    final result = await _togglePush(enabled);
    emit(
      result.fold(
        (f) => state.copyWith(isUpdatingPush: false, failure: f),
        (s) => state.copyWith(isUpdatingPush: false, settings: s),
      ),
    );
  }

  Future<void> completeOnboarding() async {
    await _completeOnboarding();
    emit(state.copyWith(settings: state.settings.copyWith(onboardingSeen: true)));
  }
}
