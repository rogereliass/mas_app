import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

class PersistentCacheEntry<T> {
  const PersistentCacheEntry({
    required this.data,
    required this.savedAt,
    required this.isExpired,
  });

  final T data;
  final DateTime? savedAt;
  final bool isExpired;
}

/// Lightweight Hive-backed snapshot cache for offline-first query reads.
class PersistentQueryCache {
  PersistentQueryCache._();

  static const String _boxName = 'query_cache_v1';
  static const String _encryptionKeyName = 'query_cache_encryption_key_v1';

  static Box<dynamic>? _box;
  static Future<void>? _opening;
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  static final Random _random = Random.secure();

  static Future<void> initialize() async {
    if (_box?.isOpen == true) return;
    _opening ??= _open();
    await _opening;
  }

  static Future<void> write({
    required String key,
    required Object? payload,
    required Duration ttl,
  }) async {
    final box = await _ensureBox();
    final now = DateTime.now();
    await box.put(key, <String, dynamic>{
      'payload': payload,
      'saved_at': now.toIso8601String(),
      'expires_at': now.add(ttl).toIso8601String(),
    });
  }

  static Future<PersistentCacheEntry<T>?> read<T>({
    required String key,
    required T? Function(Object? payload) parser,
    bool allowStale = true,
  }) async {
    final box = await _ensureBox();
    final raw = box.get(key);
    if (raw is! Map) return null;

    final dataMap = raw.map(
      (rawKey, value) => MapEntry(rawKey.toString(), value),
    );

    final expiresAt = DateTime.tryParse(
      dataMap['expires_at']?.toString() ?? '',
    );
    final isExpired = expiresAt != null && DateTime.now().isAfter(expiresAt);
    if (isExpired && !allowStale) {
      return null;
    }

    final parsed = parser(dataMap['payload']);
    if (parsed == null) {
      await box.delete(key);
      return null;
    }

    final savedAt = DateTime.tryParse(dataMap['saved_at']?.toString() ?? '');
    return PersistentCacheEntry<T>(
      data: parsed,
      savedAt: savedAt,
      isExpired: isExpired,
    );
  }

  static Future<void> invalidate(String key) async {
    final box = await _ensureBox();
    await box.delete(key);
  }

  static Future<void> clear() async {
    final box = await _ensureBox();
    await box.clear();
  }

  static Future<Box<dynamic>> _ensureBox() async {
    await initialize();
    final box = _box;
    if (box == null || !box.isOpen) {
      throw Exception('PersistentQueryCache is not initialized.');
    }
    return box;
  }

  static Future<void> _open() async {
    final key = await _getOrCreateEncryptionKey();
    final cipher = HiveAesCipher(key);

    if (Hive.isBoxOpen(_boxName)) {
      _box = Hive.box<dynamic>(_boxName);
      return;
    }

    try {
      _box = await Hive.openBox<dynamic>(_boxName, encryptionCipher: cipher);
    } catch (_) {
      // Migrate legacy unencrypted cache box to encrypted storage.
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
        _box = encrypted;
      } catch (_) {
        await Hive.deleteBoxFromDisk(_boxName);
        _box = await Hive.openBox<dynamic>(_boxName, encryptionCipher: cipher);
      }
    }
  }

  static Future<Uint8List> _getOrCreateEncryptionKey() async {
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
}
