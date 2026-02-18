import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

part 'offline_storage.g.dart';

/// Offline Storage Service
/// 
/// Manages local file caching with Hive for metadata storage
/// Handles download expiry, version tracking, and file cleanup
class OfflineStorageService {
  static const String _boxName = 'offline_files';
  static const int _defaultExpiryDays = 180;
  
  static Box<OfflineFileMetadata>? _box;

  static void _logDebug(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }

  /// Initialize Hive box for offline files
  static Future<void> initialize() async {
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(OfflineFileMetadataAdapter());
    }
    _box = await Hive.openBox<OfflineFileMetadata>(_boxName);
    
    // Clean up expired files on initialization
    await cleanupExpiredFiles();
  }

  /// Get the box instance
  static Box<OfflineFileMetadata> get box {
    if (_box == null || !_box!.isOpen) {
      throw Exception('OfflineStorageService not initialized. Call initialize() first.');
    }
    return _box!;
  }

  /// Get the directory where offline files are stored
  static Future<Directory> getOfflineDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final offlineDir = Directory('${appDir.path}/offline_files');
    
    if (!await offlineDir.exists()) {
      await offlineDir.create(recursive: true);
    }
    
    return offlineDir;
  }

  /// Save a file to local storage
  static Future<String> saveFile({
    required String fileId,
    required String fileName,
    required List<int> bytes,
    required int serverVersion,
    int expiryDays = _defaultExpiryDays,
    String? iconUrl,
  }) async {
    final offlineDir = await getOfflineDirectory();
    final filePath = '${offlineDir.path}/$fileId';
    
    // Save file bytes
    final file = File(filePath);
    await file.writeAsBytes(bytes);
    
    // Save metadata
    final metadata = OfflineFileMetadata(
      fileId: fileId,
      fileName: fileName,
      filePath: filePath,
      downloadedAt: DateTime.now(),
      expiresAt: DateTime.now().add(Duration(days: expiryDays)),
      serverVersion: serverVersion,
      sizeBytes: bytes.length,
      iconUrl: iconUrl,
    );
    
    await box.put(fileId, metadata);
    
    _logDebug('💾 Saved file offline (version: $serverVersion, expires: ${metadata.expiresAt})');
    
    return filePath;
  }

  /// Save icon image for a file
  static Future<String?> saveIcon({
    required String fileId,
    required List<int> bytes,
  }) async {
    try {
      final offlineDir = await getOfflineDirectory();
      final iconPath = '${offlineDir.path}/${fileId}_icon';
      
      final file = File(iconPath);
      await file.writeAsBytes(bytes);
      
      // Update metadata with icon path
      final metadata = box.get(fileId);
      if (metadata != null) {
        final updated = metadata.copyWith(localIconPath: iconPath);
        await box.put(fileId, updated);
      }
      
      _logDebug('🖼️ Saved icon offline');
      return iconPath;
    } catch (e) {
      _logDebug('❌ Error saving icon: $e');
      return null;
    }
  }

  /// Check if a file is available offline
  static bool isAvailableOffline(String fileId) {
    try {
      final metadata = box.get(fileId);
      if (metadata == null) return false;
      
      // Check if file exists and is not expired
      final file = File(metadata.filePath);
      final exists = file.existsSync();
      final notExpired = metadata.expiresAt.isAfter(DateTime.now());
      
      // If file is expired or doesn't exist, clean it up
      if (!exists || !notExpired) {
        deleteFile(fileId);
        return false;
      }
      
      return true;
    } catch (e) {
      _logDebug('❌ Error checking offline availability: $e');
      return false;
    }
  }

  /// Get offline file metadata
  static OfflineFileMetadata? getMetadata(String fileId) {
    return box.get(fileId);
  }

  /// Get offline file path
  static String? getFilePath(String fileId) {
    try {
      final metadata = box.get(fileId);
      if (metadata == null) return null;
      
      final file = File(metadata.filePath);
      if (!file.existsSync()) {
        // File missing, clean up metadata
        deleteFile(fileId);
        return null;
      }
      
      // Check if expired
      if (metadata.expiresAt.isBefore(DateTime.now())) {
        deleteFile(fileId);
        return null;
      }
      
      return metadata.filePath;
    } catch (e) {
      _logDebug('❌ Error getting file path: $e');
      return null;
    }
  }

  /// Check if server version is newer than cached version
  static bool needsUpdate(String fileId, int serverVersion) {
    final metadata = box.get(fileId);
    if (metadata == null) return true;
    
    return serverVersion > metadata.serverVersion;
  }

  /// Update file with new version
  static Future<String> updateFile({
    required String fileId,
    required String fileName,
    required List<int> bytes,
    required int serverVersion,
    int expiryDays = _defaultExpiryDays,
    String? iconUrl,
  }) async {
    // Delete old file first
    await deleteFile(fileId);
    
    // Save new version
    return await saveFile(
      fileId: fileId,
      fileName: fileName,
      bytes: bytes,
      serverVersion: serverVersion,
      expiryDays: expiryDays,
      iconUrl: iconUrl,
    );
  }

  /// Delete a file from local storage
  static Future<void> deleteFile(String fileId) async {
    try {
      final metadata = box.get(fileId);
      if (metadata == null) return;
      
      // Delete file
      try {
        final file = File(metadata.filePath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        _logDebug('⚠️ Error deleting file: $e');
      }
      
      // Delete icon if exists
      if (metadata.localIconPath != null) {
        try {
          final iconFile = File(metadata.localIconPath!);
          if (await iconFile.exists()) {
            await iconFile.delete();
          }
        } catch (e) {
          _logDebug('⚠️ Error deleting icon: $e');
        }
      }
      
      // Remove metadata
      await box.delete(fileId);
      
      _logDebug('🗑️ Deleted offline file');
    } catch (e) {
      _logDebug('❌ Error in deleteFile: $e');
    }
  }

  /// Clean up expired files
  static Future<void> cleanupExpiredFiles() async {
    try {
      final now = DateTime.now();
      final expiredKeys = <String>[];
      
      for (var key in box.keys) {
        try {
          final metadata = box.get(key);
          if (metadata != null && metadata.expiresAt.isBefore(now)) {
            expiredKeys.add(key);
          }
        } catch (e) {
          _logDebug('⚠️ Error checking expiry for key $key: $e');
        }
      }
      
      for (var key in expiredKeys) {
        await deleteFile(key);
      }
      
      if (expiredKeys.isNotEmpty) {
        _logDebug('🧹 Cleaned up ${expiredKeys.length} expired files');
      }
    } catch (e) {
      _logDebug('❌ Error in cleanupExpiredFiles: $e');
    }
  }

  /// Get all offline files
  static List<OfflineFileMetadata> getAllOfflineFiles() {
    return box.values.toList();
  }

  /// Get total size of offline files
  static int getTotalSize() {
    int total = 0;
    for (var metadata in box.values) {
      total += metadata.sizeBytes;
    }
    return total;
  }

  /// Clear all offline files
  static Future<void> clearAll() async {
    final keys = box.keys.toList();
    for (var key in keys) {
      await deleteFile(key);
    }
    if (kDebugMode) {
      debugPrint('🧹 Cleared all offline files');
    }
  }
}

/// Offline File Metadata Model
/// Stored in Hive to track downloaded files
@HiveType(typeId: 0)
class OfflineFileMetadata extends HiveObject {
  @HiveField(0)
  final String fileId;

  @HiveField(1)
  final String fileName;

  @HiveField(2)
  final String filePath;

  @HiveField(3)
  final DateTime downloadedAt;

  @HiveField(4)
  final DateTime expiresAt;

  @HiveField(5)
  final int serverVersion;

  @HiveField(6)
  final int sizeBytes;

  @HiveField(7)
  final String? iconUrl;

  @HiveField(8)
  final String? localIconPath;

  OfflineFileMetadata({
    required this.fileId,
    required this.fileName,
    required this.filePath,
    required this.downloadedAt,
    required this.expiresAt,
    required this.serverVersion,
    required this.sizeBytes,
    this.iconUrl,
    this.localIconPath,
  });

  OfflineFileMetadata copyWith({
    String? fileId,
    String? fileName,
    String? filePath,
    DateTime? downloadedAt,
    DateTime? expiresAt,
    int? serverVersion,
    int? sizeBytes,
    String? iconUrl,
    String? localIconPath,
  }) {
    return OfflineFileMetadata(
      fileId: fileId ?? this.fileId,
      fileName: fileName ?? this.fileName,
      filePath: filePath ?? this.filePath,
      downloadedAt: downloadedAt ?? this.downloadedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      serverVersion: serverVersion ?? this.serverVersion,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      iconUrl: iconUrl ?? this.iconUrl,
      localIconPath: localIconPath ?? this.localIconPath,
    );
  }
}
