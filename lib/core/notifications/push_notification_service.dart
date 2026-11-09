import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:injectable/injectable.dart';

/// FCM background handler — must be a top-level function.
/// Notification messages are rendered by the OS while in background.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

/// Handles FCM: token sync, foreground display through local notifications,
/// and opening the related order when a notification is tapped
/// (including cold start from a terminated state).
@lazySingleton
class PushNotificationService {
  PushNotificationService(this._messaging, this._local, this._auth, this._firestore);

  final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _local;
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  static const _channelId = 'order_status';

  final _openedOrders = StreamController<String>.broadcast();
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  String? _initialOrderId;
  bool _enabled = true;
  String _channelName = 'Orders';
  String _channelDescription = '';

  /// Order ids opened from a notification tap while the app is running.
  Stream<String> get onOrderOpened => _openedOrders.stream;

  /// Order id of the notification that launched the app (consumed once).
  String? takeInitialOrderId() {
    final id = _initialOrderId;
    _initialOrderId = null;
    return id;
  }

  Future<void> init({
    required bool enabled,
    required String channelName,
    required String channelDescription,
  }) async {
    _enabled = enabled;
    _channelName = channelName;
    _channelDescription = channelDescription;

    await _local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@drawable/ic_notification'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) => _emitFromPayload(response.payload),
    );
    await _local
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          AndroidNotificationChannel(
            _channelId,
            channelName,
            description: channelDescription,
            importance: Importance.high,
          ),
        );
    await _messaging.setForegroundNotificationPresentationOptions();

    // Cold start: app launched by tapping an FCM or local notification.
    final initialMessage = await _messaging.getInitialMessage();
    _initialOrderId = _orderIdOf(initialMessage?.data);
    final launch = await _local.getNotificationAppLaunchDetails();
    if (_initialOrderId == null && (launch?.didNotificationLaunchApp ?? false)) {
      _initialOrderId = _orderIdFromPayload(launch?.notificationResponse?.payload);
    }

    _subscriptions
      ..add(FirebaseMessaging.onMessage.listen(_showForeground))
      ..add(
        FirebaseMessaging.onMessageOpenedApp.listen((m) {
          final id = _orderIdOf(m.data);
          if (id != null) _openedOrders.add(id);
        }),
      )
      // Spec stores the FCM registration token (Admin SDK `send(token)`).
      // ignore: deprecated_member_use
      ..add(_messaging.onTokenRefresh.listen(_saveToken))
      ..add(
        _auth.authStateChanges().listen((user) {
          if (user != null && _enabled) unawaited(enable());
        }),
      );
  }

  /// Requests permission and stores the FCM token in `users/{uid}`.
  Future<void> enable() async {
    _enabled = true;
    final settings = await _messaging.requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;
    // ignore: deprecated_member_use
    final token = await _messaging.getToken();
    if (token != null) await _saveToken(token, notificationsEnabled: true);
  }

  /// Removes the token so the backend stops sending pushes.
  Future<void> disable() async {
    _enabled = false;
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      await _firestore.collection('users').doc(uid).set({
        'fcmToken': FieldValue.delete(),
        'notificationsEnabled': false,
      }, SetOptions(merge: true));
    }
    await _messaging.unregister();
  }

  /// Detaches this device from the current user (logout) without changing
  /// the user's notification preference.
  Future<void> unregister() async {
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      await _firestore.collection('users').doc(uid).set({
        'fcmToken': FieldValue.delete(),
      }, SetOptions(merge: true));
    }
    await _messaging.unregister();
  }

  Future<void> _saveToken(String token, {bool? notificationsEnabled}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || !_enabled) return;
    await _firestore.collection('users').doc(uid).set({
      'fcmToken': token,
      'notificationsEnabled': ?notificationsEnabled,
    }, SetOptions(merge: true));
  }

  Future<void> _showForeground(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null || !_enabled) return;
    await _local.show(
      id: message.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@drawable/ic_notification',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: jsonEncode(message.data),
    );
  }

  void _emitFromPayload(String? payload) {
    final id = _orderIdFromPayload(payload);
    if (id != null) _openedOrders.add(id);
  }

  static String? _orderIdOf(Map<String, dynamic>? data) => data?['orderId'] as String?;

  static String? _orderIdFromPayload(String? payload) {
    if (payload == null) return null;
    try {
      return _orderIdOf(jsonDecode(payload) as Map<String, dynamic>);
    } on FormatException catch (e) {
      debugPrint('Bad notification payload: $e');
      return null;
    }
  }

  @disposeMethod
  Future<void> dispose() async {
    for (final s in _subscriptions) {
      await s.cancel();
    }
    await _openedOrders.close();
  }
}
