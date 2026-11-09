import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:food_delivery/core/config/app_config.dart';
import 'package:food_delivery/core/network/auth_interceptor.dart';
import 'package:food_delivery/core/network/error_interceptor.dart';
import 'package:food_delivery/core/network/token_refresher.dart';
import 'package:food_delivery/core/storage/hive_boxes.dart';
import 'package:food_delivery/core/storage/token_storage.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:injectable/injectable.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

/// Registers third-party objects that cannot be annotated directly.
@module
abstract class RegisterModule {
  @lazySingleton
  FirebaseAuth get firebaseAuth => FirebaseAuth.instance;

  @lazySingleton
  FirebaseFirestore get firestore => FirebaseFirestore.instance;

  @lazySingleton
  FirebaseStorage get firebaseStorage => FirebaseStorage.instance;

  @lazySingleton
  FirebaseMessaging get firebaseMessaging => FirebaseMessaging.instance;

  @lazySingleton
  FlutterLocalNotificationsPlugin get localNotifications => FlutterLocalNotificationsPlugin();

  @lazySingleton
  FlutterSecureStorage get secureStorage => const FlutterSecureStorage();

  @lazySingleton
  Connectivity get connectivity => Connectivity();

  @lazySingleton
  ImagePicker get imagePicker => ImagePicker();

  @Named(HiveBoxes.settings)
  Box<dynamic> get settingsBox => Hive.box<dynamic>(HiveBoxes.settings);

  @Named(HiveBoxes.cart)
  Box<String> get cartBox => Hive.box<String>(HiveBoxes.cart);

  @Named(HiveBoxes.searchHistory)
  Box<String> get searchHistoryBox => Hive.box<String>(HiveBoxes.searchHistory);

  @Named(HiveBoxes.cache)
  Box<String> get cacheBox => Hive.box<String>(HiveBoxes.cache);

  @Named(HiveBoxes.address)
  Box<String> get addressBox => Hive.box<String>(HiveBoxes.address);

  @lazySingleton
  Dio dio(AppConfig config, TokenStorage tokenStorage, TokenRefresher tokenRefresher) {
    final dio = Dio(
      BaseOptions(
        baseUrl: config.functionsBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        contentType: Headers.jsonContentType,
      ),
    );
    dio.interceptors.addAll([
      AuthInterceptor(tokenStorage: tokenStorage, tokenRefresher: tokenRefresher, retryClient: dio),
      ErrorInterceptor(),
      if (config.isDev) PrettyDioLogger(requestBody: true),
    ]);
    return dio;
  }
}
