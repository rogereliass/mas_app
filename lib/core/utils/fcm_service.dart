import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';
import '../../routing/deep_link/deep_link_service.dart';
import '../../routing/navigation_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // The background isolate must initialize Firebase before using Firebase APIs.
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  debugPrint(
    'FCM background message received: ${message.messageId ?? 'no-message-id'}',
  );
}

class FcmService {
  FcmService._();

  static final FcmService instance = FcmService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedAppSubscription;

  bool _initialized = false;
  bool _backgroundHandlerRegistered = false;

  Future<void> init() async {
    if (_initialized) {
      return;
    }
    _initialized = true;

    if (!_backgroundHandlerRegistered) {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      _backgroundHandlerRegistered = true;
    }

    await requestPermission();
    await _configureForegroundPresentation();
    await getAndStoreToken();
    listenToTokenRefresh();
    await setupListeners();
  }

  Future<NotificationSettings> requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    debugPrint(
      'FCM permission status: ${settings.authorizationStatus.name}',
    );

    return settings;
  }

  Future<void> getAndStoreToken() async {
    try {
      final token = await _messaging.getToken();
      if (token == null || token.trim().isEmpty) {
        debugPrint('FCM token unavailable at startup.');
        return;
      }

      debugPrint('FCM token: $token');
      // TODO(fcm/backend): Send token to backend once token registration API is ready.
    } catch (error, stackTrace) {
      debugPrint('Failed to fetch FCM token: $error');
      debugPrint('$stackTrace');
    }
  }

  void listenToTokenRefresh() {
    _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = _messaging.onTokenRefresh.listen(
      (token) {
        if (token.trim().isEmpty) {
          debugPrint('FCM token refresh emitted an empty token.');
          return;
        }

        debugPrint('FCM token refreshed: $token');
        // TODO(fcm/backend): Send refreshed token to backend when endpoint exists.
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('FCM token refresh stream error: $error');
        debugPrint('$stackTrace');
      },
    );
  }

  Future<void> setupListeners() async {
    _foregroundSubscription?.cancel();
    _foregroundSubscription = FirebaseMessaging.onMessage.listen(
      _handleForegroundMessage,
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('FCM foreground listener error: $error');
        debugPrint('$stackTrace');
      },
    );

    _openedAppSubscription?.cancel();
    _openedAppSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      (message) {
        unawaited(_forwardToDeepLinkHandler(message));
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('FCM onMessageOpenedApp listener error: $error');
        debugPrint('$stackTrace');
      },
    );

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      await _forwardToDeepLinkHandler(initialMessage);
    }
  }

  Future<void> _configureForegroundPresentation() async {
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: false,
      badge: false,
      sound: false,
    );
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final title = message.notification?.title?.trim();
    final body = message.notification?.body?.trim();

    final textParts = <String>[];
    if (title != null && title.isNotEmpty) {
      textParts.add(title);
    }
    if (body != null && body.isNotEmpty) {
      textParts.add(body);
    }

    final inAppMessage = textParts.join(' - ');
    if (inAppMessage.isNotEmpty) {
      NavigationService.showMessage(inAppMessage);
    }

    debugPrint(
      'FCM foreground message received: '
      '${message.messageId ?? 'no-message-id'} '
      '(data keys: ${message.data.keys.toList()})',
    );
  }

  Future<void> _forwardToDeepLinkHandler(RemoteMessage message) async {
    final payload = _sanitizePayload(message.data);
    if (payload.isEmpty) {
      debugPrint(
        'FCM tap ignored because payload is empty. '
        'messageId=${message.messageId ?? 'no-message-id'}',
      );
      return;
    }

    final result = await DeepLinkService.handle(payload);
    debugPrint(
      'FCM payload handled=${result.handled} '
      'message=${result.message ?? 'none'}',
    );
  }

  Map<String, dynamic> _sanitizePayload(Map<String, dynamic> payload) {
    final sanitized = <String, dynamic>{};

    payload.forEach((key, value) {
      final normalizedKey = key.toString().trim();
      if (normalizedKey.isEmpty) {
        return;
      }
      sanitized[normalizedKey] = value;
    });

    return sanitized;
  }
}
