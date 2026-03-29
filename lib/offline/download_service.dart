import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'offline_storage.dart';

/// Download Service
/// 
/// Handles downloading files from Supabase and caching them locally
class DownloadService {
  final _supabase = Supabase.instance.client;
  static const int _defaultMaxDownloadBytes = 50 * 1024 * 1024;

  void _logDebug(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }

  /// Download a file and save it to local storage
  Future<String?> downloadAndCache({
    required String fileId,
    required String fileName,
    required String storagePath,
    required String fileType,
    required int serverVersion,
    int? fileSizeBytes,
    String? iconUrl,
    int expiryDays = 180,
    int maxSizeBytes = _defaultMaxDownloadBytes,
    Function(double)? onProgress,
  }) async {
    try {
      _logDebug('📥 Starting download (v$serverVersion)');
      
      // Don't cache video files (YouTube URLs)
      if (fileType.toLowerCase() == 'video') {
        _logDebug('⏩ Skipping video file (YouTube URL)');
        return null;
      }

      // Validate storagePath
      if (storagePath.isEmpty) {
        _logDebug('❌ Storage path is empty');
        return null;
      }

      if (fileSizeBytes != null && fileSizeBytes > maxSizeBytes) {
        _logDebug('⛔ File too large for offline cache ($fileSizeBytes bytes)');
        return null;
      }

      // Download file bytes from Supabase storage
      final bytes = await _supabase.storage
          .from('library')
          .download(storagePath);

      if (bytes.isEmpty) {
        _logDebug('❌ Downloaded file is empty');
        return null;
      }

      _logDebug('✅ Downloaded ${bytes.length} bytes');

      // Save to local storage
      final filePath = await OfflineStorageService.saveFile(
        fileId: fileId,
        fileName: fileName,
        bytes: bytes,
        serverVersion: serverVersion,
        expiryDays: expiryDays,
        iconUrl: iconUrl,
      );

      // Download icon if available
      if (iconUrl != null && iconUrl.isNotEmpty) {
        try {
          _logDebug('🖼️ Downloading icon');
          List<int>? iconBytes;

          if (!iconUrl.startsWith('http')) {
            iconBytes = await _supabase.storage.from('library').download(iconUrl);
          } else {
            final client = HttpClient();
            try {
              final request = await client.getUrl(Uri.parse(iconUrl));
              final response = await request.close();
              if (response.statusCode == HttpStatus.ok) {
                iconBytes = await consolidateHttpClientResponseBytes(response);
              }
            } finally {
              client.close(force: true);
            }
          }

          if (iconBytes != null && iconBytes.isNotEmpty) {
            await OfflineStorageService.saveIcon(
              fileId: fileId,
              bytes: iconBytes,
            );
          }
        } catch (e) {
          _logDebug('⚠️ Failed to download icon: $e');
          // Continue even if icon fails
        }
      }

      _logDebug('💾 File cached successfully');
      return filePath;
    } catch (e) {
      _logDebug('❌ Error downloading file: $e');
      return null;
    }
  }

  /// Check if file needs update and download if necessary
  Future<bool> checkAndUpdate({
    required String fileId,
    required String fileName,
    required String storagePath,
    required String fileType,
    required int serverVersion,
    int? fileSizeBytes,
    String? iconUrl,
    int expiryDays = 180,
    int maxSizeBytes = _defaultMaxDownloadBytes,
  }) async {
    // Check if we need to update
    if (!OfflineStorageService.needsUpdate(fileId, serverVersion)) {
      _logDebug('✅ File is up to date (v$serverVersion)');
      return false;
    }

    _logDebug('🔄 Updating file to v$serverVersion');

    // Download new version
    final filePath = await downloadAndCache(
      fileId: fileId,
      fileName: fileName,
      storagePath: storagePath,
      fileType: fileType,
      serverVersion: serverVersion,
      fileSizeBytes: fileSizeBytes,
      iconUrl: iconUrl,
      expiryDays: expiryDays,
      maxSizeBytes: maxSizeBytes,
    );

    return filePath != null;
  }
}
