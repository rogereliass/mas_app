import 'package:supabase_flutter/supabase_flutter.dart';
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
  Future<List<LibraryFile>> fetchFilesInFolder(String folderId) async {
    try {
      final response = await _supabase
          .from(_filesTable)
          .select()
          .eq('folder_id', folderId)
          .order('created_at', ascending: false);

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
      fetchFolderContents(String folderId) async {
    try {
      final subfolders = await fetchSubfolders(folderId);
      final files = await fetchFilesInFolder(folderId);

      return (subfolders: subfolders, files: files);
    } catch (e) {
      _logError('fetchFolderContents', e);
      rethrow;
    }
  }

  // ==================== STORAGE OPERATIONS ====================

  /// Get signed URL for a file from Supabase Storage
  /// For text files, this should NOT be called - use textContent instead
  /// 
  /// Returns signed URL valid for 1 hour
  Future<String> getFileSignedUrl(LibraryFile file) async {
    try {
      if (file.isTextFile) {
        throw Exception('Text files should not use signed URLs. Use textContent directly.');
      }

      // Storage path format: library/files/<file_id>
      final path = file.storagePath;

      final signedUrl = await _supabase.storage
          .from(_storageBucket)
          .createSignedUrl(path, 3600); // Valid for 1 hour

      return signedUrl;
    } catch (e) {
      _logError('getFileSignedUrl', e);
      rethrow;
    }
  }

  /// Download file bytes from Supabase Storage
  /// Use for actual downloads, not for viewing
  Future<List<int>> downloadFileBytes(LibraryFile file) async {
    try {
      if (file.isTextFile) {
        throw Exception('Text files should not be downloaded from storage. Use textContent directly.');
      }

      final bytes = await _supabase.storage
          .from(_storageBucket)
          .download(file.storagePath);

      return bytes;
    } catch (e) {
      _logError('downloadFileBytes', e);
      rethrow;
    }
  }

  // ==================== TRACKING OPERATIONS ====================

  /// Record a file view in the database
  /// Creates an entry in file_views table for analytics
  Future<void> recordFileView(String fileId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      
      await _supabase.from(_fileViewsTable).insert({
        'file_id': fileId,
        'user_id': userId,
        'viewed_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // Don't throw - tracking failures should not break the app
      _logError('recordFileView', e);
    }
  }

  /// Record a file download in the database
  /// Creates an entry in file_downloads table
  /// DB triggers will handle expires_at and versioning
  Future<void> recordFileDownload(String fileId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      
      await _supabase.from(_fileDownloadsTable).insert({
        'file_id': fileId,
        'user_id': userId,
        'downloaded_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // Don't throw - tracking failures should not break the app
      _logError('recordFileDownload', e);
    }
  }

  // ==================== HELPER METHODS ====================

  /// Log errors with context
  void _logError(String operation, Object error) {
    // ignore: avoid_print
    print('❌ LibraryService.$operation ERROR: $error');
    
    if (error is PostgrestException) {
      // ignore: avoid_print
      print('   Supabase Error Details: ${error.message}');
      // ignore: avoid_print
      print('   Code: ${error.code}, Hint: ${error.hint}');
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
