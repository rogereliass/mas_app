import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'library_models.dart';

/// Supabase Library Service
/// 
/// Centralized service for all Supabase operations related to the Library module
/// Handles folders, files, storage, and tracking
class LibraryService {
  static const String _storageBucket = 'library';
  static const String _foldersTable = 'folders';
  static const String _filesTable = 'files';
  static const String _fileViewsTable = 'file_views';
  static const String _fileDownloadsTable = 'file_downloads';

  final SupabaseClient _supabase;

  LibraryService(this._supabase);

  void _logDebug(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }

  /// Factory constructor using singleton Supabase instance
  factory LibraryService.instance() {
    return LibraryService(Supabase.instance.client);
  }

  // ==================== FOLDER OPERATIONS ====================

  /// Fetch root-level folders (parent_folder_id IS NULL)
  /// Returns folders sorted by name ASC
  Future<List<LibraryFolder>> fetchRootFolders() async {
    try {
      final response = await _supabase
          .from(_foldersTable)
          .select()
          .isFilter('parent_folder_id', null)
          .order('name', ascending: true);

      final folders = (response as List)
          .map((json) => LibraryFolder.fromJson(json))
          .toList();

      // Count items for each folder
      return await _enrichFoldersWithItemCount(folders);
    } catch (e) {
      _logError('fetchRootFolders', e);
      rethrow;
    }
  }

  /// Fetch subfolders for a specific parent folder
  /// Returns folders sorted by name ASC
  Future<List<LibraryFolder>> fetchSubfolders(String parentFolderId) async {
    try {
      final response = await _supabase
          .from(_foldersTable)
          .select()
          .eq('parent_folder_id', parentFolderId)
          .order('name', ascending: true);

      final folders = (response as List)
          .map((json) => LibraryFolder.fromJson(json))
          .toList();

      return await _enrichFoldersWithItemCount(folders);
    } catch (e) {
      _logError('fetchSubfolders', e);
      rethrow;
    }
  }

  /// Fetch a single folder by ID
  Future<LibraryFolder?> fetchFolderById(String folderId) async {
    try {
      final response = await _supabase
          .from(_foldersTable)
          .select()
          .eq('id', folderId)
          .single();

      return LibraryFolder.fromJson(response);
    } catch (e) {
      _logError('fetchFolderById', e);
      return null;
    }
  }

  /// Enrich folders with item count (subfolders + files)
  Future<List<LibraryFolder>> _enrichFoldersWithItemCount(
      List<LibraryFolder> folders) async {
    // DISABLED: Database has circular references or RLS issues causing stack overflow
    // Return folders with 0 count until database is fixed
    return folders.map((f) => f.copyWith(itemCount: 0)).toList();
  }

  // ==================== FILE OPERATIONS ====================

  /// Fetch files in a specific folder
  /// Returns files sorted by created_at DESC (newest first)
  Future<List<LibraryFile>> fetchFilesInFolder(
    String folderId, {
    int? limit,
    int? offset,
  }) async {
    try {
      var query = _supabase
          .from(_filesTable)
          .select()
          .eq('folder_id', folderId)
          .order('created_at', ascending: false);

      if (limit != null) {
        final start = offset ?? 0;
        final end = start + limit - 1;
        query = query.range(start, end);
      }

      final response = await query;

      return (response as List)
          .map((json) => LibraryFile.fromJson(json))
          .toList();
    } catch (e) {
      _logError('fetchFilesInFolder', e);
      rethrow;
    }
  }

  /// Fetch recent files across all folders (for home page)
  /// Returns most recent N files sorted by created_at DESC
  Future<List<LibraryFile>> fetchRecentFiles({int limit = 10}) async {
    try {
      final response = await _supabase
          .from(_filesTable)
          .select()
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List)
          .map((json) => LibraryFile.fromJson(json))
          .toList();
    } catch (e) {
      _logError('fetchRecentFiles', e);
      rethrow;
    }
  }

  /// Fetch a single file by ID
  Future<LibraryFile?> fetchFileById(String fileId) async {
    try {
      final response = await _supabase
          .from(_filesTable)
          .select()
          .eq('id', fileId)
          .single();

      return LibraryFile.fromJson(response);
    } catch (e) {
      _logError('fetchFileById', e);
      return null;
    }
  }

  /// Fetch both folders and files for root view
  /// Returns combined data for the home page
  Future<({List<LibraryFolder> folders, List<LibraryFile> recentFiles})>
      fetchRootContents({int recentFilesLimit = 10}) async {
    try {
      final folders = await fetchRootFolders();
      final recentFiles = await fetchRecentFiles(limit: recentFilesLimit);

      return (folders: folders, recentFiles: recentFiles);
    } catch (e) {
      _logError('fetchRootContents', e);
      rethrow;
    }
  }

  /// Fetch both subfolders and files for a specific folder
  /// Returns combined data for folder detail page
  Future<({List<LibraryFolder> subfolders, List<LibraryFile> files})>
      fetchFolderContents(
    String folderId, {
    int? fileLimit,
    int? fileOffset,
  }) async {
    try {
      final subfolders = await fetchSubfolders(folderId);
      final files = await fetchFilesInFolder(
        folderId,
        limit: fileLimit,
        offset: fileOffset,
      );

      return (subfolders: subfolders, files: files);
    } catch (e) {
      _logError('fetchFolderContents', e);
      rethrow;
    }
  }

  // ==================== RLS CHECKS ====================

  /// Debug-only check to detect missing RLS enforcement on files.
  /// Returns true if the query leaks any higher-rank files for the current user.
  Future<bool> hasRlsLeakForRole(int userRoleRank) async {
    if (!kDebugMode) return false;

    try {
      final response = await _supabase
          .from(_filesTable)
          .select('id,min_role_rank')
          .gt('min_role_rank', userRoleRank)
          .limit(1);

      return (response as List).isNotEmpty;
    } catch (e) {
      _logError('hasRlsLeakForRole', e);
      return false;
    }
  }

  // ==================== STORAGE OPERATIONS ====================

  /// Get signed URL for a file from Supabase Storage
  /// For text files, this should NOT be called - use textContent instead
  /// 
  /// Returns signed URL valid for 1 hour
  /// Falls back to iconUrl if storage file not found
  Future<String?> getFileSignedUrl(LibraryFile file) async {
    try {
      if (file.isTextFile) {
        throw Exception('Text files should not use signed URLs. Use textContent directly.');
      }

      if (file.storagePath == null || file.storagePath!.isEmpty) {
        _logDebug('⚠️ Storage path is null or empty');
        return file.iconUrl; // Fallback to iconUrl
      }

      final path = file.storagePath!;
      _logDebug('🔍 Attempting to get signed URL');

      try {
        // Try exact path first
        final signedUrl = await _supabase.storage
            .from(_storageBucket)
            .createSignedUrl(path, 3600); // Valid for 1 hour

        _logDebug('✅ Successfully generated signed URL');
        return signedUrl;
      } catch (storageError) {
        _logDebug('⚠️ Storage file not found at provided path');
        
        // Try with spaces replaced by underscores (common storage naming convention)
        if (path.contains(' ')) {
          final normalizedPath = path.replaceAll(' ', '_');
          _logDebug('🔄 Trying normalized path');
          
          try {
            final signedUrl = await _supabase.storage
                .from(_storageBucket)
                .createSignedUrl(normalizedPath, 3600);
            
            _logDebug('✅ Successfully generated signed URL with normalized path');
            return signedUrl;
          } catch (e) {
            _logDebug('⚠️ Normalized path also not found');
          }
        }
        
        // If storage file not found, try using iconUrl as fallback
        if (file.iconUrl != null && file.iconUrl!.isNotEmpty) {
          _logDebug('✅ Using iconUrl as fallback');
          return file.iconUrl;
        }
        
        _logDebug('❌ No iconUrl fallback available');
        rethrow;
      }
    } catch (e) {
      _logError('getFileSignedUrl', e);
      return null; // Return null instead of rethrowing to allow UI to show error
    }
  }

  /// Download file bytes from Supabase Storage
  /// Use for actual downloads, not for viewing
  Future<List<int>> downloadFileBytes(LibraryFile file) async {
    try {
      if (file.storagePath == null || file.storagePath!.isEmpty) {
        throw Exception('Storage path is null or empty');
      }

      final bytes = await _supabase.storage
          .from(_storageBucket)
          .download(file.storagePath!);

      return bytes;
    } catch (e) {
      _logError('downloadFileBytes', e);
      rethrow;
    }
  }

  /// Load text file content from storage
  /// Returns the text content as a string
  /// Used when text_content field is empty in database
  Future<String> loadTextFileContent(LibraryFile file) async {
    try {
      if (file.storagePath == null || file.storagePath!.isEmpty) {
        throw Exception('Storage path is null or empty');
      }

      _logDebug('📄 Loading text file from storage');
      
      final bytes = await _supabase.storage
          .from(_storageBucket)
          .download(file.storagePath!);

      // Use UTF-8 decoding to properly handle Arabic and other Unicode characters
      final content = utf8.decode(bytes, allowMalformed: true);
      _logDebug('✅ Loaded ${content.length} characters from text file');
      
      return content;
    } catch (e) {
      _logError('loadTextFileContent', e);
      rethrow;
    }
  }

  // ==================== TRACKING OPERATIONS ====================

  /// Record a file view in the database
  /// Creates an entry in file_views table for analytics
  /// DISABLED: file_views table missing user_id column
  Future<void> recordFileView(String fileId) async {
    try {
      // TODO: Fix file_views table schema in Supabase to include user_id column
      // final userId = _supabase.auth.currentUser?.id;
      // await _supabase.from(_fileViewsTable).insert({
      //   'file_id': fileId,
      //   'user_id': userId,
      //   'viewed_at': DateTime.now().toIso8601String(),
      // });
      _logDebug('ℹ️ File view tracking disabled (table schema issue)');
    } catch (e) {
      // Don't throw - tracking failures should not break the app
      _logError('recordFileView', e);
    }
  }

  /// Record a file download in the database
  /// Creates an entry in file_downloads table
  /// DB triggers will handle expires_at and versioning
  /// DISABLED: file_downloads table likely has same schema issue
  Future<void> recordFileDownload(String fileId) async {
    try {
      // TODO: Fix file_downloads table schema in Supabase
      // final userId = _supabase.auth.currentUser?.id;
      // await _supabase.from(_fileDownloadsTable).insert({
      //   'file_id': fileId,
      //   'user_id': userId,
      //   'downloaded_at': DateTime.now().toIso8601String(),
      // });
      _logDebug('ℹ️ File download tracking disabled (table schema issue)');
    } catch (e) {
      // Don't throw - tracking failures should not break the app
      _logError('recordFileDownload', e);
    }
  }

  // ==================== HELPER METHODS ====================

  /// Log errors with context
  void _logError(String operation, Object error) {
    if (kDebugMode) {
      debugPrint('❌ LibraryService.$operation ERROR: $error');
      if (error is PostgrestException) {
        debugPrint('   Supabase Error Details: ${error.message}');
        debugPrint('   Code: ${error.code}, Hint: ${error.hint}');
      }
    }
  }

  /// Check if storage object exists
  /// Useful for error handling with deleted files
  Future<bool> checkFileExists(String storagePath) async {
    try {
      final files = await _supabase.storage
          .from(_storageBucket)
          .list(path: storagePath);
      
      return files.isNotEmpty;
    } catch (e) {
      _logError('checkFileExists', e);
      return false;
    }
  }
}
