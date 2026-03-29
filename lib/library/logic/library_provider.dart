import 'package:flutter/foundation.dart';
import '../data/library_models.dart';
import '../data/library_service.dart';
import '../../auth/logic/auth_provider.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/data/persistent_query_cache.dart';
import '../../core/utils/ttl_cache.dart';
import '../../offline/offline_storage.dart';

/// Library Provider
/// 
/// Manages state for the Library module
/// Handles loading states, errors, and caching
/// Implements role-based file filtering
class LibraryProvider with ChangeNotifier {
  final LibraryService _service;
  final AuthProvider? _authProvider;

  LibraryProvider({LibraryService? service, AuthProvider? authProvider})
      : _service = service ?? LibraryService.instance(),
        _authProvider = authProvider;

  // ==================== STATE ====================

  // Root folders and recent files
  List<LibraryFolder> _rootFolders = [];
  List<LibraryFile> _recentFiles = [];
  List<OfflineFileMetadata> _offlineFiles = [];

  // Current folder context
  LibraryFolder? _currentFolder;
  List<LibraryFolder> _currentSubfolders = [];
  List<LibraryFile> _currentFiles = [];

  // Loading states
  bool _isLoadingRoot = false;
  bool _isLoadingFolder = false;

  // Error states
  String? _error;

  // Cache for folders and files
  final Map<String, LibraryFolder> _folderCache = {};
  final Map<String, LibraryFile> _fileCache = {};
  
  // TTL caching - track timestamps for existing caches
  static const Duration _rootContentsTtl = Duration(minutes: 3);
  static const Duration _folderContentsTtl = Duration(minutes: 2);
  static const Duration _fileMetadataTtl = Duration(minutes: 10);
  static const Duration _signedUrlTtl = Duration(minutes: 50);
  
  DateTime? _rootContentsTimestamp;
  final Map<String, DateTime> _folderTimestamps = {};
  final Map<String, DateTime> _fileTimestamps = {};
  final TtlCache<String, String> _signedUrlCache = TtlCache();

  bool _hasCheckedRls = false;

  // Pagination for files in folder
  static const int _defaultFilePageSize = 50;
  int _fileOffset = 0;
  bool _hasMoreFiles = true;
  bool _isLoadingMoreFiles = false;

  // ==================== GETTERS ====================

  List<LibraryFolder> get rootFolders => _rootFolders;
  List<LibraryFile> get recentFiles => _recentFiles;
  List<OfflineFileMetadata> get offlineFiles => List.unmodifiable(_offlineFiles);
  bool get hasOfflineFiles => _offlineFiles.isNotEmpty;

  LibraryFolder? get currentFolder => _currentFolder;
  List<LibraryFolder> get currentSubfolders => _currentSubfolders;
  List<LibraryFile> get currentFiles => _currentFiles;

  bool get isLoadingRoot => _isLoadingRoot;
  bool get isLoadingFolder => _isLoadingFolder;
  bool get isLoadingMoreFiles => _isLoadingMoreFiles;
  bool get hasMoreFiles => _hasMoreFiles;
  bool get hasError => _error != null;
  String? get error => _error;

  // ==================== ROLE-BASED FILTERING ====================
  
  /// Filter files based on current user's role rank
  /// Only returns files where user's roleRank >= file's minRoleRank
  /// Public files (minRoleRank = 0) are always visible
  List<LibraryFile> _filterFilesByRole(List<LibraryFile> files) {
    final userRoleRank = _authProvider?.currentUserRoleRank ?? 0;
    
    final filtered = files.where((file) {
      // Public files (minRoleRank = 0) are always visible
      if (file.minRoleRank == 0) return true;
      
      // Check if user has sufficient rank
      return userRoleRank >= file.minRoleRank;
    }).toList();
    
    if (filtered.length < files.length) {
      if (kDebugMode) {
        debugPrint('🔒 Filtered ${files.length - filtered.length} files based on role (user rank: $userRoleRank)');
      }
    }
    
    return filtered;
  }
  
  /// Check if current user can access a specific file
  /// Returns true if file is public or user has sufficient rank
  bool _canAccessFile(LibraryFile file) {
    if (file.minRoleRank == 0) return true; // Public file
    final userRoleRank = _authProvider?.currentUserRoleRank ?? 0;
    return userRoleRank >= file.minRoleRank;
  }

  // ==================== ROOT OPERATIONS ====================

  /// Load root folders and recent files
  /// Called on Library home page
  Future<void> loadRootContents({bool forceRefresh = false}) async {
    if (_isLoadingRoot) return;
    
    _isLoadingRoot = true;
    _error = null;
    notifyListeners();
    
    // Check cache if not forcing refresh
    if (!forceRefresh && _rootContentsTimestamp != null) {
      final now = DateTime.now();
      final elapsed = now.difference(_rootContentsTimestamp!);
      if (elapsed < _rootContentsTtl && _rootFolders.isNotEmpty) {
        _isLoadingRoot = false;
        if (kDebugMode) {
          debugPrint('📦 Using cached root contents (age: ${elapsed.inSeconds}s)');
        }
        notifyListeners();
        return;
      }
    }

    final persistedRoot = !forceRefresh
        ? await PersistentQueryCache.read<Map<String, dynamic>>(
            key: _rootSnapshotKey(),
            parser: _parseRootSnapshot,
          )
        : null;

    if (!forceRefresh && _rootFolders.isEmpty && persistedRoot != null) {
      _applyRootSnapshot(persistedRoot.data);
      _rootContentsTimestamp = persistedRoot.savedAt ?? DateTime.now();
      _isLoadingRoot = false;
      _error = null;
      notifyListeners();
      return;
    }

    if (!ConnectivityService.instance.isOnline) {
      refreshOfflineFiles(notify: false);
      _error = 'Internet connection is required to load library content.';
      _isLoadingRoot = false;
      notifyListeners();
      return;
    }

    try {
      final result = await _service.fetchRootContents(recentFilesLimit: 10);
      
      _rootFolders = result.folders;
      
      // Filter files based on user role BEFORE setting state
      final allRecentFiles = result.recentFiles;
      _recentFiles = _filterFilesByRole(allRecentFiles);

      // Cache folders
      for (final folder in _rootFolders) {
        _folderCache[folder.id] = folder;
      }

      // Cache ALL files (even filtered ones) for direct access
      for (final file in allRecentFiles) {
        _fileCache[file.id] = file;
        _fileTimestamps[file.id] = DateTime.now();
      }
      
      // Mark root contents as cached
      _rootContentsTimestamp = DateTime.now();

      await PersistentQueryCache.write(
        key: _rootSnapshotKey(),
        payload: _buildRootSnapshotPayload(),
        ttl: _rootContentsTtl,
      );

      _isLoadingRoot = false;
      _error = null;

      if (kDebugMode && !_hasCheckedRls) {
        _hasCheckedRls = true;
        final roleRank = _authProvider?.currentUserRoleRank ?? 0;
        final hasLeak = await _service.hasRlsLeakForRole(roleRank);
        if (hasLeak) {
          debugPrint('⚠️ RLS may be disabled: higher-rank files were visible to current user');
        } else {
          debugPrint('✅ RLS check passed or no higher-rank files found');
        }
      }
    } catch (e) {
      if (_rootFolders.isEmpty && persistedRoot != null) {
        _applyRootSnapshot(persistedRoot.data);
        _rootContentsTimestamp = persistedRoot.savedAt ?? DateTime.now();
        _error = null;
      } else {
        _error = _formatError(e);
      }
      _isLoadingRoot = false;
    }

    notifyListeners();
  }

  /// Refresh root contents (pull-to-refresh)
  Future<void> refreshRootContents({bool forceRefresh = false}) async {
    return loadRootContents(forceRefresh: forceRefresh);
  }

  // ==================== FOLDER OPERATIONS ====================

  /// Load folder contents (subfolders and files)
  /// Called when navigating into a folder
  Future<void> loadFolderContents(String folderId, {bool forceRefresh = false}) async {
    if (_isLoadingFolder) return;
    
    _isLoadingFolder = true;
    _error = null;
    _fileOffset = 0;
    _hasMoreFiles = true;
    notifyListeners();
    
    // Check cache if not forcing refresh and not currently viewing different folder
    if (!forceRefresh && 
        _currentFolder?.id == folderId && 
        _folderTimestamps.containsKey(folderId)) {
      final now = DateTime.now();
      final elapsed = now.difference(_folderTimestamps[folderId]!);
      if (elapsed < _folderContentsTtl && _currentFiles.isNotEmpty) {
        _isLoadingFolder = false;
        if (kDebugMode) {
          debugPrint('📦 Using cached folder contents for $folderId (age: ${elapsed.inSeconds}s)');
        }
        notifyListeners();
        return;
      }
    }

    final folderSnapshotKey = _folderSnapshotKey(folderId);
    final persistedFolder = !forceRefresh
        ? await PersistentQueryCache.read<Map<String, dynamic>>(
            key: folderSnapshotKey,
            parser: _parseFolderSnapshot,
          )
        : null;

    if (!forceRefresh && persistedFolder != null) {
      _applyFolderSnapshot(folderId, persistedFolder.data);
      _folderTimestamps[folderId] = persistedFolder.savedAt ?? DateTime.now();
      _isLoadingFolder = false;
      _error = null;
      notifyListeners();
      return;
    }

    if (!ConnectivityService.instance.isOnline) {
      refreshOfflineFiles(notify: false);
      _error = 'Internet connection is required to load this folder.';
      _isLoadingFolder = false;
      notifyListeners();
      return;
    }

    try {
      // Load folder details if not in cache
      if (!_folderCache.containsKey(folderId)) {
        final folder = await _service.fetchFolderById(folderId);
        if (folder != null) {
          _folderCache[folderId] = folder;
        }
      }

      _currentFolder = _folderCache[folderId];

      // Load folder contents
      final result = await _service.fetchFolderContents(
        folderId,
        fileLimit: _defaultFilePageSize,
        fileOffset: _fileOffset,
      );
      
      _currentSubfolders = result.subfolders;
      
      // Filter files based on user role BEFORE setting state
      final allFiles = result.files;
      _currentFiles = _filterFilesByRole(allFiles);
      _hasMoreFiles = allFiles.length == _defaultFilePageSize;

      // Cache subfolders
      for (final folder in _currentSubfolders) {
        _folderCache[folder.id] = folder;
      }

      // Cache ALL files (even filtered ones) for direct access
      for (final file in allFiles) {
        _fileCache[file.id] = file;
        _fileTimestamps[file.id] = DateTime.now();
      }
      
      // Mark folder contents as cached
      _folderTimestamps[folderId] = DateTime.now();

      await PersistentQueryCache.write(
        key: folderSnapshotKey,
        payload: _buildFolderSnapshotPayload(folderId),
        ttl: _folderContentsTtl,
      );

      _isLoadingFolder = false;
      _error = null;
    } catch (e) {
      if (persistedFolder != null) {
        _applyFolderSnapshot(folderId, persistedFolder.data);
        _folderTimestamps[folderId] = persistedFolder.savedAt ?? DateTime.now();
        _error = null;
      } else {
        _error = _formatError(e);
      }
      _isLoadingFolder = false;
    }

    notifyListeners();
  }

  /// Load next page of files in the current folder
  Future<void> loadMoreFiles() async {
    if (_isLoadingMoreFiles || !_hasMoreFiles || _currentFolder == null) {
      return;
    }

    if (!ConnectivityService.instance.isOnline) {
      // Keep existing cached folder content visible while offline.
      // Pagination failure should not switch the page into a full error state.
      notifyListeners();
      return;
    }

    _isLoadingMoreFiles = true;
    notifyListeners();

    try {
      _fileOffset += _defaultFilePageSize;
      final nextFiles = await _service.fetchFilesInFolder(
        _currentFolder!.id,
        limit: _defaultFilePageSize,
        offset: _fileOffset,
      );

      _hasMoreFiles = nextFiles.length == _defaultFilePageSize;

      // Cache ALL files (even filtered ones) for direct access
      for (final file in nextFiles) {
        _fileCache[file.id] = file;
        _fileTimestamps[file.id] = DateTime.now();
      }

      // Append filtered files to current list
      final filteredNextFiles = _filterFilesByRole(nextFiles);
      _currentFiles = [..._currentFiles, ...filteredNextFiles];
    } catch (e) {
      _logError('loadMoreFiles', e);
    } finally {
      _isLoadingMoreFiles = false;
      notifyListeners();
    }
  }

  /// Refresh current folder contents
  Future<void> refreshFolderContents({bool forceRefresh = false}) async {
    if (_currentFolder != null) {
      return loadFolderContents(_currentFolder!.id, forceRefresh: forceRefresh);
    }
  }

  /// Clear current folder context
  /// Called when navigating back to root
  void clearCurrentFolder() {
    _currentFolder = null;
    _currentSubfolders = [];
    _currentFiles = [];
    _fileOffset = 0;
    _hasMoreFiles = true;
    notifyListeners();
  }

  // ==================== FILE OPERATIONS ====================

  /// Get file by ID from cache or fetch from server
  /// Returns null if file not found OR user doesn't have access
  Future<LibraryFile?> getFile(String fileId, {bool forceRefresh = false}) async {
    // Check cache first (with TTL)
    if (!forceRefresh && _fileCache.containsKey(fileId) && _fileTimestamps.containsKey(fileId)) {
      final now = DateTime.now();
      final elapsed = now.difference(_fileTimestamps[fileId]!);
      
      if (elapsed < _fileMetadataTtl) {
        final file = _fileCache[fileId]!;
        
        // Verify access even for cached files
        if (!_canAccessFile(file)) {
          if (kDebugMode) {
            debugPrint('🔒 Access denied to file $fileId (requires rank ${file.minRoleRank})');
          }
          return null;
        }
        
        if (kDebugMode) {
          debugPrint('📦 Using cached file metadata for $fileId (age: ${elapsed.inMinutes}min)');
        }
        return file;
      }
    }

    // Fetch from server
    try {
      final file = await _service.fetchFileById(fileId);
      if (file != null) {
        _fileCache[fileId] = file;
        _fileTimestamps[fileId] = DateTime.now();
        
        // Verify access to fetched file
        if (!_canAccessFile(file)) {
          if (kDebugMode) {
            debugPrint('🔒 Access denied to file $fileId (requires rank ${file.minRoleRank})');
          }
          return null;
        }
        
        return file;
      }
      return null;
    } catch (e) {
      _logError('getFile', e);
      return null;
    }
  }

  /// Get signed URL for a file
  /// Returns null for text files or on error
  /// Falls back to iconUrl if storage file not found
  Future<String?> getFileUrl(String fileId, {bool forceRefresh = false}) async {
    try {
      final file = await getFile(fileId, forceRefresh: forceRefresh);
      if (file == null) {
        if (kDebugMode) {
          debugPrint('⚠️ File not found or access denied: $fileId');
        }
        return null;
      }

      // Text files should not use signed URLs
      if (file.isTextFile) {
        return null;
      }
      
      // Check signed URL cache
      if (!forceRefresh) {
        final cachedUrl = _signedUrlCache.get(fileId);
        if (cachedUrl != null) {
          if (kDebugMode) {
            debugPrint('📦 Using cached signed URL for $fileId');
          }
          return cachedUrl;
        }
      }

      final url = await _service.getFileSignedUrl(file);
      
      if (url == null || url.isEmpty) {
        if (kDebugMode) {
          debugPrint('⚠️ No URL generated for file: ${file.title}');
        }
        return null;
      }
      
      // Cache signed URL (50min TTL)
      _signedUrlCache.set(fileId, url, _signedUrlTtl);
      
      return url;
    } catch (e) {
      _logError('getFileUrl', e);
      return null;
    }
  }

  /// Get text content for a text file
  /// First tries textContent field, then loads from storage if empty
  Future<String?> getTextFileContent(String fileId) async {
    try {
      final file = await getFile(fileId);
      if (file == null) return null;

      // If text_content is populated in database, use it
      if (file.textContent != null && file.textContent!.isNotEmpty) {
        if (kDebugMode) {
          debugPrint('✅ Using text_content from database (${file.textContent!.length} chars)');
        }
        return file.textContent;
      }

      // Otherwise, load from storage
      if (kDebugMode) {
        debugPrint('📄 text_content empty, loading from storage...');
      }
      final content = await _service.loadTextFileContent(file);
      return content;
    } catch (e) {
      _logError('getTextFileContent', e);
      return null;
    }
  }

  /// Download file bytes
  Future<List<int>?> downloadFile(String fileId) async {
    try {
      final file = await getFile(fileId);
      if (file == null) return null;

      // Record download
      await _service.recordFileDownload(fileId);

      // For text files, convert text content to bytes
      if (file.isTextFile && file.textContent != null) {
        return file.textContent!.codeUnits;
      }

      // Download from storage
      return await _service.downloadFileBytes(file);
    } catch (e) {
      _logError('downloadFile', e);
      return null;
    }
  }

  /// Record file view
  /// Call this when user opens a file
  Future<void> recordFileView(String fileId) async {
    try {
      await _service.recordFileView(fileId);
    } catch (e) {
      _logError('recordFileView', e);
    }
  }

  // ==================== HELPER METHODS ====================

  /// Format error for display
  String _formatError(Object error) {
    if (error.toString().contains('No rows')) {
      return 'No data found';
    }
    if (error.toString().contains('network')) {
      return 'Network error. Please check your connection.';
    }
    return 'An error occurred. Please try again.';
  }

  /// Log errors
  void _logError(String operation, Object error) {
    if (kDebugMode) {
      debugPrint('❌ LibraryProvider.$operation ERROR: $error');
    }
  }

  /// Clear all caches
  void clearCache() {
    _folderCache.clear();
    _fileCache.clear();
    _rootContentsTimestamp = null;
    _folderTimestamps.clear();
    _fileTimestamps.clear();
    _signedUrlCache.clear();
    notifyListeners();
  }

  String _cacheUserKey() {
    final userId = _authProvider?.currentUser?.id.trim();
    if (userId == null || userId.isEmpty) {
      return 'guest';
    }
    return userId;
  }

  String _rootSnapshotKey() => 'library:${_cacheUserKey()}:root_contents';

  String _folderSnapshotKey(String folderId) =>
      'library:${_cacheUserKey()}:folder:$folderId';

  Map<String, dynamic>? _parseRootSnapshot(Object? payload) {
    if (payload is! Map) return null;
    return payload.map((key, value) => MapEntry(key.toString(), value));
  }

  Map<String, dynamic>? _parseFolderSnapshot(Object? payload) {
    if (payload is! Map) return null;
    return payload.map((key, value) => MapEntry(key.toString(), value));
  }

  Map<String, dynamic> _buildRootSnapshotPayload() {
    return <String, dynamic>{
      'folders': _rootFolders.map((folder) => folder.toJson()).toList(growable: false),
      'recent_files': _recentFiles.map((file) => file.toJson()).toList(growable: false),
    };
  }

  Map<String, dynamic> _buildFolderSnapshotPayload(String folderId) {
    return <String, dynamic>{
      'folder_id': folderId,
      'current_folder': _currentFolder?.toJson(),
      'subfolders': _currentSubfolders
          .map((folder) => folder.toJson())
          .toList(growable: false),
      'files': _currentFiles.map((file) => file.toJson()).toList(growable: false),
      'file_offset': _fileOffset,
      'has_more_files': _hasMoreFiles,
    };
  }

  void _applyRootSnapshot(Map<String, dynamic> payload) {
    final folders = _parseFolders(payload['folders']);
    final recentFiles = _parseFiles(payload['recent_files']);

    _rootFolders = folders;
    _recentFiles = _filterFilesByRole(recentFiles);

    for (final folder in folders) {
      _folderCache[folder.id] = folder;
    }

    for (final file in recentFiles) {
      _fileCache[file.id] = file;
      _fileTimestamps[file.id] = DateTime.now();
    }
  }

  void _applyFolderSnapshot(String folderId, Map<String, dynamic> payload) {
    final currentFolder = _parseOptionalFolder(payload['current_folder']);
    final subfolders = _parseFolders(payload['subfolders']);
    final files = _parseFiles(payload['files']);

    _currentFolder = currentFolder ?? _folderCache[folderId];
    _currentSubfolders = subfolders;
    _currentFiles = _filterFilesByRole(files);
    _fileOffset = _parseInt(payload['file_offset']);
    _hasMoreFiles = _parseBool(payload['has_more_files']);

    if (_currentFolder != null) {
      _folderCache[_currentFolder!.id] = _currentFolder!;
    }

    for (final folder in subfolders) {
      _folderCache[folder.id] = folder;
    }

    for (final file in files) {
      _fileCache[file.id] = file;
      _fileTimestamps[file.id] = DateTime.now();
    }
  }

  List<LibraryFolder> _parseFolders(Object? payload) {
    if (payload is! List) return const <LibraryFolder>[];

    return payload
        .whereType<Map>()
        .map((row) => row.map((key, value) => MapEntry(key.toString(), value)))
        .map(LibraryFolder.fromJson)
        .toList(growable: false);
  }

  List<LibraryFile> _parseFiles(Object? payload) {
    if (payload is! List) return const <LibraryFile>[];

    return payload
        .whereType<Map>()
        .map((row) => row.map((key, value) => MapEntry(key.toString(), value)))
        .map(LibraryFile.fromJson)
        .toList(growable: false);
  }

  LibraryFolder? _parseOptionalFolder(Object? payload) {
    if (payload is! Map) return null;
    final map = payload.map((key, value) => MapEntry(key.toString(), value));
    return LibraryFolder.fromJson(map);
  }

  int _parseInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  bool _parseBool(Object? value) {
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true';
    return false;
  }

  void refreshOfflineFiles({bool notify = true}) {
    final isAuthenticated = _authProvider?.isAuthenticated ?? false;
    if (!isAuthenticated) {
      _offlineFiles = const <OfflineFileMetadata>[];
      if (notify) {
        notifyListeners();
      }
      return;
    }

    final files = OfflineStorageService.getAllOfflineFiles()
        .where((file) {
          if (!OfflineStorageService.isAvailableOffline(file.fileId)) {
            return false;
          }

          final cachedFile = _fileCache[file.fileId];
          if (cachedFile == null) {
            // Allow authenticated users to see downloaded files even after
            // cold restart when in-memory metadata has not been hydrated yet.
            return true;
          }

          return _canAccessFile(cachedFile);
        })
        .toList(growable: false)
      ..sort((a, b) => b.downloadedAt.compareTo(a.downloadedAt));

    _offlineFiles = files;

    if (notify) {
      notifyListeners();
    }
  }
  
  /// Re-apply role-based filtering to current data
  /// Call this when user authentication state changes (login/logout)
  void refreshFiltering() {
    // Re-filter recent files
    if (_recentFiles.isNotEmpty) {
      final allRecentFiles = _fileCache.values
          .where((file) => _recentFiles.any((f) => f.id == file.id))
          .toList();
      _recentFiles = _filterFilesByRole(allRecentFiles);
    }
    
    // Re-filter current folder files
    if (_currentFiles.isNotEmpty) {
      final allCurrentFiles = _fileCache.values
          .where((file) => _currentFiles.any((f) => f.id == file.id))
          .toList();
      _currentFiles = _filterFilesByRole(allCurrentFiles);
    }
    
    if (kDebugMode) {
      debugPrint('🔄 Reapplied role-based filtering (user rank: ${_authProvider?.currentUserRoleRank ?? 0})');
    }
    notifyListeners();
  }
}

