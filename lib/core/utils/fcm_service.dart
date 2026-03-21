import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../firebase_options.dart';
import '../../home/pages/notifications/data/token_repository.dart';
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
  final TokenRepository _tokenRepository = TokenRepository();

  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedAppSubscription;

  final Set<String> _handledMessageIds = <String>{};
  String? _currentProfileId;
  String? _lastRegisteredToken;

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
    listenToTokenRefresh();
    await setupListeners();
  }

  Future<void> syncTokenForProfile({required String profileId}) async {
    final normalizedProfileId = profileId.trim();
    if (normalizedProfileId.isEmpty) {
      return;
    }

    _currentProfileId = normalizedProfileId;

    if (!_isSupabaseReady()) {
      debugPrint('FCM token sync skipped because Supabase is not initialized yet.');
      return;
    }

    await getAndStoreToken();
  }

  Future<void> clearTokenForSignedOutUser() async {
    // Keep token rows on sign-out by decision; only reset in-memory binding.
    _currentProfileId = null;
    _lastRegisteredToken = null;
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

      await _registerToken(token);
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

        unawaited(_registerToken(token));
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
    if (_isDuplicateMessage(message)) {
      return;
    }

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
    if (_isDuplicateMessage(message)) {
      return;
    }

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

  Future<void> _registerToken(String token) async {
    final normalizedToken = token.trim();
    if (normalizedToken.isEmpty) {
      return;
    }

    final profileId = _currentProfileId;
    if (profileId == null || profileId.isEmpty) {
      debugPrint('FCM token registration postponed: profile is not ready yet.');
      return;
    }

    if (!_isSupabaseReady()) {
      debugPrint('FCM token registration skipped: Supabase is not initialized yet.');
      return;
    }

    if (_lastRegisteredToken == normalizedToken) {
      return;
    }

    final deviceType = _resolveDeviceType();
    if (deviceType == null) {
      debugPrint('FCM token registration skipped: unsupported platform.');
      return;
    }

    try {
      await _tokenRepository.upsertDeviceToken(
        profileId: profileId,
        fcmToken: normalizedToken,
        deviceType: deviceType,
      );
      _lastRegisteredToken = normalizedToken;
      debugPrint('FCM token registered for profile $profileId ($deviceType).');
    } catch (error, stackTrace) {
      debugPrint('FCM token backend registration failed: $error');
      debugPrint('$stackTrace');
    }
  }

  String? _resolveDeviceType() {
    if (kIsWeb) {
      return 'web';
    }

    if (Platform.isIOS) {
      return 'ios';
    }

    if (Platform.isAndroid) {
      return 'android';
    }

    return null;
  }

  bool _isSupabaseReady() {
    try {
      Supabase.instance.client;
      return true;
    } catch (_) {
      return false;
    }
  }

  bool _isDuplicateMessage(RemoteMessage message) {
    final messageId = message.messageId?.trim();
    if (messageId == null || messageId.isEmpty) {
      return false;
    }

    if (_handledMessageIds.contains(messageId)) {
      return true;
    }

    _handledMessageIds.add(messageId);
    if (_handledMessageIds.length > 200) {
      _handledMessageIds.remove(_handledMessageIds.first);
    }

    return false;
  }
}
