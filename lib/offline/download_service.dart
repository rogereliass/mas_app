import 'package:supabase_flutter/supabase_flutter.dart';
import 'offline_storage.dart';

/// Download Service
/// 
/// Handles downloading files from Supabase and caching them locally
class DownloadService {
  final _supabase = Supabase.instance.client;

  /// Download a file and save it to local storage
  Future<String?> downloadAndCache({
    required String fileId,
    required String fileName,
    required String storagePath,
    required String fileType,
    required int serverVersion,
    String? iconUrl,
    int expiryDays = 180,
    Function(double)? onProgress,
  }) async {
    try {
      print('📥 Starting download: $fileName (v$serverVersion)');
      
      // Don't cache video files (YouTube URLs)
      if (fileType.toLowerCase() == 'video') {
        print('⏩ Skipping video file (YouTube URL)');
        return null;
      }

      // Validate storagePath
      if (storagePath.isEmpty) {
        print('❌ Storage path is empty');
        return null;
      }

      // Download file bytes from Supabase storage
      final bytes = await _supabase.storage
          .from('library')
          .download(storagePath);

      if (bytes.isEmpty) {
        print('❌ Downloaded file is empty');
        return null;
      }

      print('✅ Downloaded ${bytes.length} bytes');

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
          print('🖼️ Downloading icon from: $iconUrl');
          // Note: iconUrl is expected to be a full URL, not a storage path
          // You might need to adjust this based on your Supabase setup
          
          // If iconUrl is a storage path, download from Supabase
          if (!iconUrl.startsWith('http')) {
            final iconBytes = await _supabase.storage
                .from('library')
                .download(iconUrl);
            
            if (iconBytes.isNotEmpty) {
              await OfflineStorageService.saveIcon(
                fileId: fileId,
                bytes: iconBytes,
              );
            }
          }
        } catch (e) {
          print('⚠️ Failed to download icon: $e');
          // Continue even if icon fails
        }
      }

      print('💾 File cached successfully: $filePath');
      return filePath;
    } catch (e) {
      print('❌ Error downloading file: $e');
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
    String? iconUrl,
    int expiryDays = 180,
  }) async {
    // Check if we need to update
    if (!OfflineStorageService.needsUpdate(fileId, serverVersion)) {
      print('✅ File is up to date (v$serverVersion)');
      return false;
    }

    print('🔄 Updating file from v${OfflineStorageService.getMetadata(fileId)?.serverVersion ?? 0} to v$serverVersion');

    // Download new version
    final filePath = await downloadAndCache(
      fileId: fileId,
      fileName: fileName,
      storagePath: storagePath,
      fileType: fileType,
      serverVersion: serverVersion,
      iconUrl: iconUrl,
      expiryDays: expiryDays,
    );

    return filePath != null;
  }
}
