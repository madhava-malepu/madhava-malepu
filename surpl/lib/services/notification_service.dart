import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'dart:typed_data';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '/auth/firebase_auth/auth_util.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  if (message.notification == null && message.data['type'] == 'new_order') {
    await NotificationService.showIncomingOrderAlert(message);
  }
}

class PendingNotificationNav {
  static String? type;
  static String? id;

  static void setFromMessageData(Map<String, dynamic> data) {
    final t = data['type'] as String?;
    final orderId = data['orderId'] as String?;
    final bagId = data['bagId'] as String?;
    if (t == 'new_order' || t == 'order_update') {
      type = t;
      id = orderId;
    } else if (t == 'new_bag') {
      type = t;
      id = bagId;
    }
  }

  static void setFromPayloadString(String? payload) {
    if (payload == null || !payload.contains(':')) return;
    final parts = payload.split(':');
    type = parts[0];
    id = parts.sublist(1).join(':');
  }

  static void clear() {
    type = null;
    id = null;
  }
}

class NotificationService {
  static final _messaging = FirebaseMessaging.instance;
  static final _localNotifications = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;


    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    await _messaging.requestPermission(
      alert: true, badge: true, sound: true);

    await _ensureLocalInitialized();
    final launchDetails = await _localNotifications.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp == true) {
      PendingNotificationNav.setFromPayloadString(
          launchDetails?.notificationResponse?.payload);
    }

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      PendingNotificationNav.setFromMessageData(message.data);
    });

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      PendingNotificationNav.setFromMessageData(initialMessage.data);
    }

    FirebaseMessaging.onMessage.listen((message) {
      if (message.data['type'] == 'new_order') {
        showIncomingOrderAlert(message);
        return;
      }
      final notification = message.notification;
      final android = message.notification?.android;
      if (notification != null && android != null) {
        final serverChannelId = android.channelId;
        final isCustomerChannel = serverChannelId == 'surpl_order_updates';
        _localNotifications.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              isCustomerChannel ? 'surpl_order_updates' : 'surpl_orders_v2',
              isCustomerChannel ? 'Order Updates' : 'Surpl Orders',
              channelDescription: isCustomerChannel
                  ? 'Updates on your Surpl order status'
                  : 'Order updates for vendors',
              importance: Importance.max,
              priority: Priority.high,
              icon: 'ic_stat_surpl',
            )),
          payload: '${message.data['type'] ?? ''}:${message.data['orderId'] ?? message.data['bagId'] ?? ''}',
        );
      }
    });

    await _saveToken();

    _messaging.onTokenRefresh.listen(_saveTokenString);
    _initialized = true;
  }

  static bool _localInitialized = false;
  static Future<void> _ensureLocalInitialized() async {
    if (_localInitialized) return;
    final androidChannel = AndroidNotificationChannel(
      'surpl_orders_v2',
      'Surpl Orders',
      description: 'Order updates for vendors',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 400, 200, 400, 200, 400]),
    );

    final urgentChannel = AndroidNotificationChannel(
      'surpl_orders_urgent',
      'Surpl Incoming Orders',
      description: 'A paid order needs your acceptance right now',
      importance: Importance.max,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound('order_alert'),
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 500, 200, 500, 200, 500, 200, 500]),
    );

    final customerChannel = AndroidNotificationChannel(
      'surpl_order_updates',
      'Order Updates',
      description: 'Updates on your Surpl order status',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(urgentChannel);
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(customerChannel);

    await _localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_surpl')),
      onDidReceiveNotificationResponse: (response) {
        PendingNotificationNav.setFromPayloadString(response.payload);
      },
    );

    _localInitialized = true;
  }
  static const _settings = MethodChannel('surpl/notification_settings');
  static Future<Map<String, dynamic>> alertStatus() async {
    try { return Map<String,dynamic>.from(await _settings.invokeMethod('status') as Map); }
    catch (_) { return {'available': false}; }
  }
  static Future<void> openAlertSettings() async { await _settings.invokeMethod('open'); }
  static Future<void> testOrderSound() async {
    await _ensureLocalInitialized();
    await _localNotifications.show(73535, 'SURPL order sound test', 'This is a test, not a customer order.',
      const NotificationDetails(android: AndroidNotificationDetails('surpl_orders_urgent', 'Surpl Incoming Orders',
        importance: Importance.max, priority: Priority.high, sound: RawResourceAndroidNotificationSound('order_alert'), icon: 'ic_stat_surpl')));
  }

  static Future<void> showIncomingOrderAlert(RemoteMessage message) async {
    await _ensureLocalInitialized();
    final orderId = message.data['orderId'] as String?;
    if (orderId == null || orderId.isEmpty) return;
    final bagTitle = message.data['bagTitle'] as String? ?? 'a Surprise Bag';
    final amount = message.data['amount'] as String? ?? '';

    await _localNotifications.show(
      orderId.hashCode,
      'New Order! \ud83d\udd14',
      amount.isNotEmpty ? '$bagTitle — Rs.$amount. Tap to accept.' : '$bagTitle. Tap to accept.',
      NotificationDetails(
        android: AndroidNotificationDetails(
          'surpl_orders_urgent',
          'Surpl Incoming Orders',
          channelDescription: 'A paid order needs your acceptance right now',
          importance: Importance.max,
          priority: Priority.high,
          category: AndroidNotificationCategory.reminder,
          sound: const RawResourceAndroidNotificationSound('order_alert'),
          enableVibration: true,
          icon: 'ic_stat_surpl',
        ),
      ),
      payload: 'new_order:$orderId',
    );
  }

  static Future<void> saveTokenForCurrentUser() async {
    await _saveToken();
  }

  static Future<void> _saveToken() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) await _saveTokenString(token);
    } catch (e) {
      debugPrint('FCM token save failed: $e');
    }
  }

  static Future<void> _saveTokenString(String token) async {
    try {
      final uid = currentUserUid;
      if (uid.isEmpty) return;
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'fcmToken': token,
        'fcmUpdatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('FCM token Firestore write failed: $e');
    }
  }

  static Future<void> notifyVendorNewOrder({
    required String vendorUid,
    required String bagTitle,
    required double amount,
    required String orderId,
    required String pickupCode,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('vendorNotifications').add({
        'vendorUid': vendorUid,
        'type': 'new_order',
        'title': 'New Order! Code: $pickupCode',
        'body': '"$bagTitle" — Rs.${amount.toStringAsFixed(0)}. Pickup code: $pickupCode',
        'orderId': orderId,
        'pickupCode': pickupCode,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  static Stream<int> unreadCount(String vendorUid) {
    return FirebaseFirestore.instance
        .collection('vendorNotifications')
        .where('vendorUid', isEqualTo: vendorUid)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  static Future<void> markAllRead(String vendorUid) async {
    final snap = await FirebaseFirestore.instance
        .collection('vendorNotifications')
        .where('vendorUid', isEqualTo: vendorUid)
        .where('read', isEqualTo: false)
        .get();
    for (final doc in snap.docs) {
      await doc.reference.update({'read': true});
    }
  }
}
