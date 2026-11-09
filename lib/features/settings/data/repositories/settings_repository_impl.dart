import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:food_delivery/core/config/app_config.dart';
import 'package:food_delivery/core/error/exception_mapper.dart';
import 'package:food_delivery/core/notifications/push_notification_service.dart';
import 'package:food_delivery/core/usecase/usecase.dart';
import 'package:food_delivery/features/settings/data/datasources/settings_local_data_source.dart';
import 'package:food_delivery/features/settings/domain/entities/app_settings.dart';
import 'package:food_delivery/features/settings/domain/repositories/settings_repository.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:package_info_plus/package_info_plus.dart';

@LazySingleton(as: SettingsRepository)
class SettingsRepositoryImpl implements SettingsRepository {
  SettingsRepositoryImpl(this._local, this._push, this._auth, this._firestore, this._config);

  final SettingsLocalDataSource _local;
  final PushNotificationService _push;
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final AppConfig _config;

  @override
  AppSettings load() => _local.read();

  @override
  Future<void> save(AppSettings settings) => _local.write(settings);

  @override
  FutureEither<Unit> setPushEnabled({required bool enabled}) => guard(() async {
    if (enabled) {
      await _push.enable();
    } else {
      await _push.disable();
    }
    return unit;
  });

  @override
  FutureEither<Unit> syncLanguage(AppLanguage language) => guard(() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return unit;
    await _firestore.collection('users').doc(uid).set({
      'language': language.name,
    }, SetOptions(merge: true));
    return unit;
  });

  @override
  Future<AppInfo> appInfo() async {
    final info = await PackageInfo.fromPlatform();
    return AppInfo(
      version: info.version,
      buildNumber: info.buildNumber,
      flavor: _config.flavor.name,
      showFlavor: _config.isDev,
    );
  }
}
