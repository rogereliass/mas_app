import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:masapp/core/constants/offline_policy.dart';
import 'package:masapp/core/services/connectivity_service.dart';
import 'package:masapp/routing/navigation_service.dart';
import 'package:uuid/uuid.dart';

typedef OfflineActionHandler = Future<void> Function(
  Map<String, dynamic> payload,
);
typedef OfflineActionValidator = bool Function(Map<String, dynamic> payload);

class OfflineQueuedAction {
  const OfflineQueuedAction({
    required this.id,
    required this.type,
    required this.payload,
    required this.createdAt,
    required this.retryCount,
    required this.fingerprint,
    this.nextAttemptAt,
    this.lastError,
    this.isFailed = false,
  });

  final String id;
  final String type;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final int retryCount;
  final String fingerprint;
  final DateTime? nextAttemptAt;
  final String? lastError;
  final bool isFailed;

  OfflineQueuedAction copyWith({
    int? retryCount,
    DateTime? nextAttemptAt,
    String? lastError,
    bool? isFailed,
  }) {
    return OfflineQueuedAction(
      id: id,
      type: type,
      payload: payload,
      createdAt: createdAt,
      retryCount: retryCount ?? this.retryCount,
      fingerprint: fingerprint,
      nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
      lastError: lastError ?? this.lastError,
      isFailed: isFailed ?? this.isFailed,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'type': type,
      'payload': payload,
      'createdAt': createdAt.toIso8601String(),
      'retryCount': retryCount,
      'fingerprint': fingerprint,
      'nextAttemptAt': nextAttemptAt?.toIso8601String(),
      'lastError': lastError,
      'isFailed': isFailed,
    };
  }

  factory OfflineQueuedAction.fromMap(Map<dynamic, dynamic> map) {
    return OfflineQueuedAction(
      id: (map['id'] ?? '') as String,
      type: (map['type'] ?? '') as String,
      payload: Map<String, dynamic>.from(
        (map['payload'] ?? <String, dynamic>{}) as Map,
      ),
      createdAt: DateTime.tryParse((map['createdAt'] ?? '') as String) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      retryCount: (map['retryCount'] as int?) ?? 0,
      fingerprint: (map['fingerprint'] ?? '') as String,
      nextAttemptAt: DateTime.tryParse((map['nextAttemptAt'] ?? '') as String),
      lastError: map['lastError'] as String?,
      isFailed: (map['isFailed'] as bool?) ?? false,
    );
  }
}

class OfflineActionQueue extends ChangeNotifier {
  OfflineActionQueue._();

  static final OfflineActionQueue instance = OfflineActionQueue._();

  static const String _boxName = 'offline_action_queue';
  static const String _encryptionKeyName = 'offline_queue_encryption_key_v1';
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  final Uuid _uuid = const Uuid();
  final math.Random _random = math.Random.secure();
  final List<OfflineQueuedAction> _items = <OfflineQueuedAction>[];
  final Map<String, OfflineActionHandler> _handlers =
      <String, OfflineActionHandler>{};
  final Map<String, OfflineActionValidator> _validators =
      <String, OfflineActionValidator>{};

  Box<dynamic>? _box;
  StreamSubscription<bool>? _connectivitySubscription;
  bool _initialized = false;
  bool _isProcessing = false;

  int get pendingCount => _items.length;
  int get failedCount => _items.where((item) => item.isFailed).length;
  bool get isProcessing => _isProcessing;
  List<OfflineQueuedAction> get pendingActions => List.unmodifiable(_items);

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    _box = await _openQueueBox();
    _loadFromStorage();

    _connectivitySubscription = ConnectivityService.instance.statusStream.listen(
      (online) {
        if (online) {
          unawaited(processQueue());
        }
      },
    );

    if (ConnectivityService.instance.isOnline) {
      unawaited(processQueue());
    }
  }

  void registerHandler(String type, OfflineActionHandler handler) {
    _handlers[type] = handler;
    if (ConnectivityService.instance.isOnline) {
      unawaited(processQueue());
    }
  }

  void registerValidator(String type, OfflineActionValidator validator) {
    _validators[type] = validator;
  }

  Future<bool> enqueue({
    required String type,
    required Map<String, dynamic> payload,
    String? id,
    bool isDestructive = false,
  }) async {
    if (isDestructive) {
      throw Exception('Internet required for destructive actions.');
    }

    final actionId = id ?? _uuid.v4();
    final fingerprint = _buildFingerprint(type: type, payload: payload);

    final duplicateIndex = _items.indexWhere(
      (item) => item.id == actionId || item.fingerprint == fingerprint,
    );
    if (duplicateIndex >= 0) {
      final duplicate = _items[duplicateIndex];
      if (duplicate.isFailed) {
        await _remove(duplicate.id);
      } else {
        return false;
      }
    }

    if (_items.any((item) => item.id == actionId || item.fingerprint == fingerprint)) {
      return false;
    }

    final action = OfflineQueuedAction(
      id: actionId,
      type: type,
      payload: payload,
      createdAt: DateTime.now(),
      retryCount: 0,
      fingerprint: fingerprint,
    );

    _items.add(action);
    await _persist(action);
    notifyListeners();
    return true;
  }

  Future<void> processQueue() async {
    if (!ConnectivityService.instance.isOnline || _isProcessing || _items.isEmpty) {
      return;
    }

    _isProcessing = true;
    notifyListeners();

    var syncedCount = 0;
    var failedCount = 0;
    final now = DateTime.now();

    try {
      final snapshot = [..._items]..sort((a, b) => a.createdAt.compareTo(b.createdAt));

      for (final action in snapshot) {
        if (action.isFailed) {
          continue;
        }

        final nextAttemptAt = action.nextAttemptAt;
        if (nextAttemptAt != null && nextAttemptAt.isAfter(now)) {
          continue;
        }

        final handler = _handlers[action.type];
        if (handler == null) {
          continue;
        }

        final validator = _validators[action.type];
        if (validator != null && !validator(action.payload)) {
          await _remove(action.id);
          continue;
        }

        try {
          await handler(action.payload);
          await _remove(action.id);
          syncedCount += 1;
        } catch (e) {
          final retryCount = action.retryCount + 1;
          if (retryCount >= OfflinePolicy.maxQueueRetries) {
            final failed = action.copyWith(
              retryCount: retryCount,
              nextAttemptAt: null,
              lastError: _toErrorString(e),
              isFailed: true,
            );
            await _persist(failed);
            failedCount += 1;
            continue;
          }

          final baseSeconds = (1 << retryCount).clamp(2, 60);
          final jitterSeconds = _random.nextInt(3);
          final backoff = Duration(seconds: baseSeconds + jitterSeconds);

          final updated = action.copyWith(retryCount: retryCount);
          final retrying = updated.copyWith(
            nextAttemptAt: DateTime.now().add(backoff),
            lastError: _toErrorString(e),
            isFailed: false,
          );
          await _persist(retrying);
          _replaceInMemory(retrying);
        }
      }
    } finally {
      _isProcessing = false;
      notifyListeners();
    }

    if (syncedCount > 0) {
      NavigationService.showMessage('Synced successfully');
    }
    if (failedCount > 0) {
      NavigationService.showMessage(
        'Some offline actions failed and need manual retry',
      );
    }
  }

  Future<void> clear() async {
    _items.clear();
    await _box?.clear();
    notifyListeners();
  }

  Future<void> retryFailedActions() async {
    final failedActions = _items.where((item) => item.isFailed).toList(growable: false);
    if (failedActions.isEmpty) {
      return;
    }

    for (final action in failedActions) {
      final reset = action.copyWith(
        retryCount: 0,
        nextAttemptAt: null,
        lastError: null,
        isFailed: false,
      );
      await _persist(reset);
    }

    if (ConnectivityService.instance.isOnline) {
      await processQueue();
    } else {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    unawaited(_connectivitySubscription?.cancel());
    unawaited(_box?.close());
    super.dispose();
  }

  void _loadFromStorage() {
    _items
      ..clear()
      ..addAll(
        (_box?.values ?? const <dynamic>[])
            .whereType<Map>()
            .map((value) => OfflineQueuedAction.fromMap(value))
            .where((action) => action.id.isNotEmpty && action.type.isNotEmpty),
      );
    notifyListeners();
  }

  Future<void> _persist(OfflineQueuedAction action) async {
    await _box?.put(action.id, action.toMap());
    _replaceInMemory(action);
  }

  Future<void> _remove(String id) async {
    _items.removeWhere((item) => item.id == id);
    await _box?.delete(id);
  }

  void _replaceInMemory(OfflineQueuedAction action) {
    final index = _items.indexWhere((item) => item.id == action.id);
    if (index >= 0) {
      _items[index] = action;
    } else {
      _items.add(action);
    }
  }

  String _buildFingerprint({
    required String type,
    required Map<String, dynamic> payload,
  }) {
    final canonicalPayload = _canonicalize(payload);
    return '$type::${jsonEncode(canonicalPayload)}';
  }

  Object? _canonicalize(Object? value) {
    if (value is Map) {
      final sortedKeys = value.keys.map((e) => e.toString()).toList()..sort();
      return <String, Object?>{
        for (final key in sortedKeys)
          key: _canonicalize(value[key]),
      };
    }

    if (value is List) {
      return value.map(_canonicalize).toList(growable: false);
    }

    return value;
  }

  Future<Box<dynamic>> _openQueueBox() async {
    final key = await _getOrCreateEncryptionKey();
    final cipher = HiveAesCipher(key);

    try {
      return await Hive.openBox<dynamic>(_boxName, encryptionCipher: cipher);
    } catch (_) {
      // Migrate legacy unencrypted queue box to encrypted storage.
      try {
        final legacy = await Hive.openBox<dynamic>(_boxName);
        final legacyEntries = Map<dynamic, dynamic>.from(legacy.toMap());
        await legacy.close();
        await Hive.deleteBoxFromDisk(_boxName);

        final encrypted = await Hive.openBox<dynamic>(
          _boxName,
          encryptionCipher: cipher,
        );
        if (legacyEntries.isNotEmpty) {
          await encrypted.putAll(legacyEntries);
        }
        return encrypted;
      } catch (_) {
        await Hive.deleteBoxFromDisk(_boxName);
        return Hive.openBox<dynamic>(_boxName, encryptionCipher: cipher);
      }
    }
  }

  Future<Uint8List> _getOrCreateEncryptionKey() async {
    final existing = await _secureStorage.read(key: _encryptionKeyName);
    if (existing != null && existing.isNotEmpty) {
      try {
        final decoded = base64Url.decode(existing);
        if (decoded.length == 32) {
          return Uint8List.fromList(decoded);
        }
      } catch (_) {
        // Fall through to regenerate invalid key material.
      }
    }

    final generated = List<int>.generate(32, (_) => _random.nextInt(256));
    final encoded = base64UrlEncode(generated);
    await _secureStorage.write(key: _encryptionKeyName, value: encoded);
    return Uint8List.fromList(generated);
  }

  String _toErrorString(Object error) {
    final message = error.toString().trim();
    return message.isEmpty ? 'Unknown offline queue error' : message;
  }
}
