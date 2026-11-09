import 'dart:async';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:food_delivery/app.dart';
import 'package:food_delivery/core/config/app_config.dart';
import 'package:food_delivery/core/config/firebase_env_options.dart';
import 'package:food_delivery/core/di/injection.dart';
import 'package:food_delivery/core/error/error_reporter.dart';
import 'package:food_delivery/core/l10n/gen/app_localizations.dart';
import 'package:food_delivery/core/notifications/push_notification_service.dart';
import 'package:food_delivery/core/router/app_router.dart';
import 'package:food_delivery/core/router/routes.dart';
import 'package:food_delivery/core/storage/hive_boxes.dart';
import 'package:food_delivery/features/address/presentation/bloc/address_cubits.dart';
import 'package:food_delivery/features/auth/presentation/bloc/session_cubit.dart';
import 'package:food_delivery/features/cart/presentation/bloc/cart_cubit.dart';
import 'package:food_delivery/features/settings/domain/entities/app_settings.dart';
import 'package:food_delivery/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:material_ui/material_ui.dart';

/// Shared startup for every flavor (`main_dev.dart`, `main_prod.dart`).
Future<void> bootstrap(Flavor flavor) async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.fromEnvironment(flavor);

  await Firebase.initializeApp(options: FirebaseEnvOptions.currentPlatform);
  if (config.useEmulator) _useEmulators(config.emulatorHost);

  // Every unexpected error goes to Crashlytics (disabled in debug builds).
  final crashlytics = FirebaseCrashlytics.instance;
  await crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode);
  FlutterError.onError = crashlytics.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    unawaited(crashlytics.recordError(error, stack, fatal: true));
    return true;
  };
  ErrorReporter.sink = (error, stack) => unawaited(crashlytics.recordError(error, stack));

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  await HiveBoxes.init();
  configureDependencies(config);

  // Restore global state before the first frame.
  final settings = getIt<SettingsCubit>().state.settings;
  final l10n = lookupAppLocalizations(Locale(settings.language?.name ?? AppLanguage.uz.name));
  final push = getIt<PushNotificationService>();
  await push.init(
    enabled: settings.notificationsEnabled,
    channelName: l10n.notificationChannelName,
    channelDescription: l10n.notificationChannelDescription,
  );
  await getIt<SessionCubit>().start();
  await getIt<CartCubit>().load();
  getIt<CurrentAddressCubit>().load();

  // Cold start from a notification tap opens that order directly.
  final initialOrder = push.takeInitialOrderId();
  final router = createRouter(
    session: getIt<SessionCubit>(),
    initialLocation: initialOrder == null ? Routes.splash : Routes.order(initialOrder),
  );

  runApp(App(router: router));
}

void _useEmulators(String host) {
  FirebaseAuth.instance.useAuthEmulator(host, 9099);
  FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
  FirebaseStorage.instance.useStorageEmulator(host, 9199);
}
