import 'package:flutter/foundation.dart';
import '../data/library_models.dart';
import '../data/library_service.dart';

/// Library Provider
/// 
/// Manages state for the Library module
/// Handles loading states, errors, and caching
class LibraryProvider with ChangeNotifier {
  final LibraryService _service;

  LibraryProvider({LibraryService? service})
      : _service = service ?? LibraryService.instance();

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

  // ==================== GETTERS ====================

  List<LibraryFolder> get rootFolders => _rootFolders;
  List<LibraryFile> get recentFiles => _recentFiles;

  LibraryFolder? get currentFolder => _currentFolder;
  List<LibraryFolder> get currentSubfolders => _currentSubfolders;
  List<LibraryFile> get currentFiles => _currentFiles;

  bool get isLoadingRoot => _isLoadingRoot;
  bool get isLoadingFolder => _isLoadingFolder;
  bool get hasError => _error != null;
  String? get error => _error;

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
      _recentFiles = result.recentFiles;

      // Cache folders
      for (final folder in _rootFolders) {
        _folderCache[folder.id] = folder;
      }

      // Cache files
      for (final file in _recentFiles) {
        _fileCache[file.id] = file;
      }

      _isLoadingRoot = false;
      _error = null;
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
      final result = await _service.fetchFolderContents(folderId);
      
      _currentSubfolders = result.subfolders;
      _currentFiles = result.files;

      // Cache subfolders
      for (final folder in _currentSubfolders) {
        _folderCache[folder.id] = folder;
      }

      // Cache files
      for (final file in _currentFiles) {
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
    notifyListeners();
  }

  // ==================== FILE OPERATIONS ====================

  /// Get file by ID from cache or fetch from server
  Future<LibraryFile?> getFile(String fileId) async {
    // Check cache first
    if (_fileCache.containsKey(fileId)) {
      return _fileCache[fileId];
    }

    // Fetch from server
    try {
      final file = await _service.fetchFileById(fileId);
      if (file != null) {
        _fileCache[fileId] = file;
      }
      return file;
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
        print('⚠️ File not found: $fileId');
        return null;
      }

      // Text files should not use signed URLs
      if (file.isTextFile) {
        return null;
      }

      final url = await _service.getFileSignedUrl(file);
      
      if (url == null || url.isEmpty) {
        print('⚠️ No URL generated for file: ${file.title}');
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
        print('✅ Using text_content from database (${file.textContent!.length} chars)');
        return file.textContent;
      }

      // Otherwise, load from storage
      print('📄 text_content empty, loading from storage...');
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
      print('❌ LibraryProvider.$operation ERROR: $error');
    }
  }

  /// Clear all caches
  void clearCache() {
    _folderCache.clear();
    _fileCache.clear();
    notifyListeners();
  }
}

