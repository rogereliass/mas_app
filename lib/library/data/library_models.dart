/// Library Folder Model
/// Maps to the 'folders' table in Supabase
class LibraryFolder {
  final String id;
  final String name;
  final String? parentFolderId;
  final int? depth;
  final DateTime createdAt;
  final int itemCount; // Computed - not from DB

  LibraryFolder({
    required this.id,
    required this.name,
    this.parentFolderId,
    this.depth,
    required this.createdAt,
    this.itemCount = 0,
  });

  factory LibraryFolder.fromJson(Map<String, dynamic> json) {
    return LibraryFolder(
      id: json['id'] as String,
      name: json['name'] as String,
      parentFolderId: json['parent_folder_id'] as String?,
      depth: json['depth'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
      itemCount: 0, // Will be computed separately
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'parent_folder_id': parentFolderId,
      'depth': depth,
      'created_at': createdAt.toIso8601String(),
    };
  }

  LibraryFolder copyWith({
    String? id,
    String? name,
    String? parentFolderId,
    int? depth,
    DateTime? createdAt,
    int? itemCount,
  }) {
    return LibraryFolder(
      id: id ?? this.id,
      name: name ?? this.name,
      parentFolderId: parentFolderId ?? this.parentFolderId,
      depth: depth ?? this.depth,
      createdAt: createdAt ?? this.createdAt,
      itemCount: itemCount ?? this.itemCount,
    );
  }
}

/// Library File Model
/// Maps to the 'files' table in Supabase
class LibraryFile {
  final String id;
  final String? folderId;
  final String title;
  final String? description;
  final String? fileType;
  final String? storagePath;
  final int? sizeBytes;
  final String? iconUrl;
  final String? visibilityRoleId;
  final List<String>? allowedRoles;
  final String? textContent; // For text files
  final int? serverVersion;
  final List<String>? tags;
  final bool? downloadsAllowed;
  final DateTime createdAt;

  LibraryFile({
    required this.id,
    this.folderId,
    required this.title,
    this.description,
    this.fileType,
    this.storagePath,
    this.sizeBytes,
    this.iconUrl,
    this.visibilityRoleId,
    this.allowedRoles,
    this.textContent,
    this.serverVersion,
    this.tags,
    this.downloadsAllowed,
    required this.createdAt,
  });

  factory LibraryFile.fromJson(Map<String, dynamic> json) {
    return LibraryFile(
      id: json['id'] as String,
      folderId: json['folder_id'] as String?,
      title: json['title'] as String,
      description: json['description'] as String?,
      fileType: json['file_type'] as String?,
      storagePath: json['storage_path'] as String?,
      sizeBytes: json['size_bytes'] as int?,
      iconUrl: json['icon_url'] as String?,
      visibilityRoleId: json['visibility_role_id'] as String?,
      allowedRoles: json['allowed_roles'] != null
          ? List<String>.from(json['allowed_roles'] as List)
          : null,
      textContent: json['text_content'] as String?,
      serverVersion: json['server_version'] as int?,
      tags: json['tags'] != null
          ? List<String>.from(json['tags'] as List)
          : null,
      downloadsAllowed: json['downloads_allowed'] as bool?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'folder_id': folderId,
      'title': title,
      'description': description,
      'file_type': fileType,
      'storage_path': storagePath,
      'size_bytes': sizeBytes,
      'icon_url': iconUrl,
      'visibility_role_id': visibilityRoleId,
      'allowed_roles': allowedRoles,
      'text_content': textContent,
      'server_version': serverVersion,
      'tags': tags,
      'downloads_allowed': downloadsAllowed,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Check if file is a text file that should be rendered directly
  bool get isTextFile {
    if (fileType == null) return false;
    final type = fileType!.toLowerCase();
    return type == 'text' || type == 'txt';
  }

  /// Get formatted file size
  String get formattedSize {
    if (sizeBytes == null) return 'Unknown';
    if (sizeBytes! < 1024) return '${sizeBytes}B';
    if (sizeBytes! < 1024 * 1024) {
      return '${(sizeBytes! / 1024).toStringAsFixed(1)}KB';
    }
    return '${(sizeBytes! / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  LibraryFile copyWith({
    String? id,
    String? folderId,
    String? title,
    String? description,
    String? fileType,
    String? storagePath,
    int? sizeBytes,
    String? iconUrl,
    String? visibilityRoleId,
    List<String>? allowedRoles,
    String? textContent,
    int? serverVersion,
    List<String>? tags,
    bool? downloadsAllowed,
    DateTime? createdAt,
  }) {
    return LibraryFile(
      id: id ?? this.id,
      folderId: folderId ?? this.folderId,
      title: title ?? this.title,
      description: description ?? this.description,
      fileType: fileType ?? this.fileType,
      storagePath: storagePath ?? this.storagePath,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      iconUrl: iconUrl ?? this.iconUrl,
      visibilityRoleId: visibilityRoleId ?? this.visibilityRoleId,
      allowedRoles: allowedRoles ?? this.allowedRoles,
      textContent: textContent ?? this.textContent,
      serverVersion: serverVersion ?? this.serverVersion,
      tags: tags ?? this.tags,
      downloadsAllowed: downloadsAllowed ?? this.downloadsAllowed,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
