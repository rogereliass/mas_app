import 'package:flutter/foundation.dart';
import '../data/library_models.dart';
import '../data/library_service.dart';
import '../../auth/logic/auth_provider.dart';

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

  bool _hasCheckedRls = false;

  // Pagination for files in folder
  static const int _defaultFilePageSize = 50;
  int _fileOffset = 0;
  bool _hasMoreFiles = true;
  bool _isLoadingMoreFiles = false;

  // ==================== GETTERS ====================

  List<LibraryFolder> get rootFolders => _rootFolders;
  List<LibraryFile> get recentFiles => _recentFiles;

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
      debugPrint('🔒 Filtered ${files.length - filtered.length} files based on role (user rank: $userRoleRank)');
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
  Future<void> loadRootContents() async {
    if (_isLoadingRoot) return;

    _isLoadingRoot = true;
    _error = null;
    notifyListeners();

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
      }

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
      _error = _formatError(e);
      _isLoadingRoot = false;
    }

    notifyListeners();
  }

  /// Refresh root contents (pull-to-refresh)
  Future<void> refreshRootContents() async {
    return loadRootContents();
  }

  // ==================== FOLDER OPERATIONS ====================

  /// Load folder contents (subfolders and files)
  /// Called when navigating into a folder
  Future<void> loadFolderContents(String folderId) async {
    if (_isLoadingFolder) return;

    _isLoadingFolder = true;
    _error = null;
    _fileOffset = 0;
    _hasMoreFiles = true;
    notifyListeners();

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
      }

      _isLoadingFolder = false;
      _error = null;
    } catch (e) {
      _error = _formatError(e);
      _isLoadingFolder = false;
    }

    notifyListeners();
  }

  /// Load next page of files in the current folder
  Future<void> loadMoreFiles() async {
    if (_isLoadingMoreFiles || !_hasMoreFiles || _currentFolder == null) {
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
  Future<void> refreshFolderContents() async {
    if (_currentFolder != null) {
      return loadFolderContents(_currentFolder!.id);
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
  Future<LibraryFile?> getFile(String fileId) async {
    // Check cache first
    if (_fileCache.containsKey(fileId)) {
      final file = _fileCache[fileId]!;
      
      // Verify access even for cached files
      if (!_canAccessFile(file)) {
        debugPrint('🔒 Access denied to file $fileId (requires rank ${file.minRoleRank})');
        return null;
      }
      
      return file;
    }

    // Fetch from server
    try {
      final file = await _service.fetchFileById(fileId);
      if (file != null) {
        _fileCache[fileId] = file;
        
        // Verify access to fetched file
        if (!_canAccessFile(file)) {
          debugPrint('🔒 Access denied to file $fileId (requires rank ${file.minRoleRank})');
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
  Future<String?> getFileUrl(String fileId) async {
    try {
      final file = await getFile(fileId);
      if (file == null) {
        debugPrint('⚠️ File not found or access denied: $fileId');
        return null;
      }

      // Text files should not use signed URLs
      if (file.isTextFile) {
        return null;
      }

      final url = await _service.getFileSignedUrl(file);
      
      if (url == null || url.isEmpty) {
        debugPrint('⚠️ No URL generated for file: ${file.title}');
      }
      
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
        debugPrint('✅ Using text_content from database (${file.textContent!.length} chars)');
        return file.textContent;
      }

      // Otherwise, load from storage
      debugPrint('📄 text_content empty, loading from storage...');
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
    notifyListeners();
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
    
    debugPrint('🔄 Reapplied role-based filtering (user rank: ${_authProvider?.currentUserRoleRank ?? 0})');
    notifyListeners();
  }
}

