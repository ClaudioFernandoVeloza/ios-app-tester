import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:pic_collector/models/friend.dart';
import 'package:pic_collector/models/user_profile.dart';
import 'package:pic_collector/screens/main-features/friend_profile_screen.dart';
import 'package:pic_collector/screens/main-features/friend_requests_screen.dart';
import 'package:pic_collector/services/user_profile_service.dart';

/// Global navigator key attached to the root [MaterialApp] so notifications
/// can navigate no matter which screen is on top (including when the app is
/// opened straight from a notification tap).
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// Android channel id. Must match the `default_notification_channel_id` meta
/// value in AndroidManifest.xml so background/system notifications land on the
/// same high-importance channel as our foreground ones.
const String kNotificationChannelId = 'friend_activity';

/// Background handler. Runs in a separate isolate when the app is killed or in
/// the background and a message arrives.
///
/// For a `notification` payload the OS already draws the banner, so there is
/// nothing to do here. We register it anyway so any future `data`-only message
/// is handled without crashing (and to satisfy firebase_messaging's contract).
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  debugPrint('FCM background message: ${message.messageId}');
}

class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _tokensOf(String uid) =>
      _db.collection('users').doc(uid).collection('fcmTokens');

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Initializes messaging + local notifications. Safe to call once at startup.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // Ask the OS for permission (Android 13+ / iOS). No-op where not needed.
    try {
      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (e) {
      debugPrint('requestPermission failed: $e');
    }

    // Create the high-importance channel so heads-up banners appear at the top
    // of the screen (Android 8+ requires a channel; max importance = heads-up).
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          kNotificationChannelId,
          'Friend activity',
          description: 'Friend requests and accepted requests',
          importance: Importance.max,
        ),
      );
    }

    // Initialise local notifications (used only for the FOREGROUND case).
    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _localNotifications.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (response) {
        _routeFromPayload(response.payload);
      },
    );

    // Foreground: OS will not draw the banner, so we do it ourselves.
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    // Background -> user taps the system banner.
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _routeFromData(message.data);
    });

    // Token management: persist the current token and keep it fresh.
    await _saveTokenIfSignedIn();
    _messaging.onTokenRefresh.listen((_) {
      _saveTokenIfSignedIn();
    });

    // Cold start: app launched by tapping a system banner.
    try {
      final initial = await _messaging.getInitialMessage();
      if (initial != null) _routeFromData(initial.data);
    } catch (e) {
      debugPrint('getInitialMessage failed: $e');
    }
  }

  /// Saves the device token for the current user. Call right after login or
  /// sign-up so the backend can start targeting this device immediately.
  Future<void> attachToCurrentUser() => _saveTokenIfSignedIn();

  /// Removes this device's token for the current user. Call BEFORE sign-out
  /// (while the uid is still known) so the backend stops targeting it.
  Future<void> clearCurrentUser() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final token = await _messaging.getToken();
      if (token != null) await _tokensOf(uid).doc(token).delete();
    } catch (e) {
      debugPrint('FCM token clear failed: $e');
    }
  }

  Future<void> _saveTokenIfSignedIn() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final token = await _messaging.getToken();
      if (token == null) return;
      await _tokensOf(uid).doc(token).set({
        'token': token,
        'platform': defaultTargetPlatform.name,
        'createdAt': FieldValue.serverTimestamp(),
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('FCM token save failed: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Foreground banner (heads-up while the app is open)
  // ---------------------------------------------------------------------------

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return; // data-only: nothing to draw

    final androidDetails = AndroidNotificationDetails(
      kNotificationChannelId,
      'Friend activity',
      channelDescription: 'Friend requests and accepted requests',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    await _localNotifications.show(
      id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title: notification.title,
      body: notification.body,
      notificationDetails: NotificationDetails(
        android: androidDetails,
        iOS: const DarwinNotificationDetails(),
      ),
      payload: jsonEncode(message.data),
    );
  }

  // ---------------------------------------------------------------------------
  // Routing
  // ---------------------------------------------------------------------------

  void _routeFromPayload(String? payload) {
    if (payload == null) return;
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      _routeFromData(data);
    } catch (e) {
      debugPrint('Bad notification payload: $e');
    }
  }

  /// Navigates based on the `data` map attached to a notification. Waits until
  /// the root navigator exists (covers cold-start launches where the first
  /// frame has not been built yet).
  Future<void> _routeFromData(Map<String, dynamic> data) async {
    print("etimastou");
    print(data);
    final navigator = await _waitForNavigator();
    if (navigator == null) return;

    final type = data['type'] as String?;
    final fromUid = data['fromUid'] as String?;

    if (type == 'friend_accepted' && (fromUid?.isNotEmpty ?? false)) {
      // Open the profile of the person who accepted.
      try {
        final profile =
            await UserProfileService.instance.getUserProfile(fromUid!);
        if (profile != null) {
          navigator.push(
            MaterialPageRoute(
              builder: (_) => FriendProfileScreen(friend: _friendOf(profile)),
            ),
          );
          return;
        }
      } catch (e) {
        debugPrint('Could not load profile for notification: $e');
      }
    }

    // Default (friend_request) and any fallback: open the request inbox.
    navigator.push(
      MaterialPageRoute(builder: (_) => const FriendRequestsScreen()),
    );
  }

  Future<NavigatorState?> _waitForNavigator({
    int attempts = 20,
    Duration delay = const Duration(milliseconds: 250),
  }) async {
    for (var i = 0; i < attempts; i++) {
      final state = appNavigatorKey.currentState;
      if (state != null) return state;
      await Future<void>.delayed(delay);
    }
    return null;
  }

  /// Mirrors the `_friendFromProfile` helper in friends_screen so a real
  /// [UserProfile] can open [FriendProfileScreen].
  Friend _friendOf(UserProfile profile) {
    final name = profile.fullName.trim();
    return Friend(
      name: name.isNotEmpty ? name : profile.username,
      username: profile.username,
      email: profile.email,
      color: Colors.blue,
    );
  }
}

