import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/notification_models.dart';

class NotificationService {
  NotificationService(this._supabase);

  static const String _notificationsTable = 'notifications';
  static const String _recipientsTable = 'notification_recipients';
  static const String _profilesTable = 'profiles';

  final SupabaseClient _supabase;

  factory NotificationService.instance() {
    return NotificationService(Supabase.instance.client);
  }

  Future<Map<String, dynamic>?> fetchActiveSeason() async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return _supabase
        .from('seasons')
        .select('id, name, start_date, end_date')
        .lte('start_date', today)
        .gte('end_date', today)
        .limit(1)
        .maybeSingle();
  }

  Future<List<NotificationRecipientEntry>> fetchNotificationsForProfile({
    required String profileId,
    int limit = 50,
  }) async {
    final response = await _supabase
        .from(_recipientsTable)
        .select('''
          id,
          notification_id,
          profile_id,
          read,
          read_at,
          created_at,
          delivered,
          delivered_at,
          notifications!inner(
            id,
            type,
            title,
            body,
            data,
            created_by_profile_id,
            created_at,
            season_id,
            target_type,
            target_id
          )
        ''')
        .eq('profile_id', profileId)
        .order('created_at', referencedTable: _notificationsTable, ascending: false)
        .limit(limit);

    return (response as List)
        .map((item) => NotificationRecipientEntry.fromJoinedJson(
              Map<String, dynamic>.from(item as Map),
            ))
        .toList();
  }

  Future<int> fetchUnreadCount({required String profileId}) async {
    final response = await _supabase
        .from(_recipientsTable)
        .select('id')
        .eq('profile_id', profileId)
        .eq('read', false);

    return (response as List).length;
  }

  Future<void> markRecipientRead({required String recipientId}) async {
    await _supabase
        .from(_recipientsTable)
        .update({
          'read': true,
          'read_at': DateTime.now().toIso8601String(),
        })
        .eq('id', recipientId);
  }

  Future<void> markAllRead({required String profileId}) async {
    await _supabase
        .from(_recipientsTable)
        .update({
          'read': true,
          'read_at': DateTime.now().toIso8601String(),
        })
        .eq('profile_id', profileId)
        .eq('read', false);
  }

  Future<String> createNotificationRow({
    required String createdByProfileId,
    required String seasonId,
    required NotificationCreateRequest request,
  }) async {
    final response = await _supabase
        .from(_notificationsTable)
        .insert({
          'type': request.type.value,
          'title': request.title,
          'body': request.body,
          'data': request.data,
          'created_by_profile_id': createdByProfileId,
          'season_id': seasonId,
          'target_type': request.targetType.value,
          'target_id': request.targetId,
        })
        .select('id')
        .single();

    return response['id'] as String;
  }

  Future<void> deleteNotificationById(String notificationId) async {
    await _supabase.from(_notificationsTable).delete().eq('id', notificationId);
  }

  Future<List<String>> resolveRecipientProfileIds({
    required NotificationTargetType targetType,
    required String? targetId,
    required int senderRoleRank,
    required String? senderTroopId,
  }) async {
    _validateSenderTargetScope(
      targetType: targetType,
      targetId: targetId,
      senderRoleRank: senderRoleRank,
      senderTroopId: senderTroopId,
    );

    switch (targetType) {
      case NotificationTargetType.all:
        return _fetchAllApprovedProfileIds();
      case NotificationTargetType.troop:
        return _fetchTroopProfileIds(targetId!);
      case NotificationTargetType.patrol:
        return _fetchPatrolProfileIds(targetId!);
      case NotificationTargetType.individual:
        return _fetchIndividualProfileIds(targetId!);
      case NotificationTargetType.role:
        return _fetchRoleProfileIds(targetId!);
    }
  }

  Future<void> insertRecipientRows({
    required String notificationId,
    required List<String> recipientProfileIds,
  }) async {
    if (recipientProfileIds.isEmpty) {
      return;
    }

    final now = DateTime.now().toIso8601String();
    final rows = recipientProfileIds
        .map(
          (profileId) => <String, dynamic>{
            'notification_id': notificationId,
            'profile_id': profileId,
            'delivered': true,
            'delivered_at': now,
            'read': false,
            'read_at': null,
            'created_at': now,
          },
        )
        .toList();

    await _supabase.from(_recipientsTable).upsert(
      rows,
      onConflict: 'notification_id,profile_id',
      ignoreDuplicates: true,
    );
  }

  Future<List<NotificationTargetOption>> fetchTroopTargetOptions() async {
    final response = await _supabase
        .from('troops')
        .select('id, name')
        .order('name', ascending: true);

    return (response as List)
        .map((row) {
          final map = Map<String, dynamic>.from(row as Map);
          return NotificationTargetOption(
            id: map['id'] as String,
            label: (map['name'] as String? ?? '').trim(),
          );
        })
        .toList();
  }

  Future<NotificationTargetOption?> fetchTroopTargetOptionById({
    required String troopId,
  }) async {
    final response = await _supabase
        .from('troops')
        .select('id, name')
        .eq('id', troopId)
        .maybeSingle();

    if (response == null) {
      return null;
    }

    return NotificationTargetOption(
      id: response['id'] as String,
      label: (response['name'] as String? ?? '').trim(),
    );
  }

  Future<List<NotificationTargetOption>> fetchPatrolTargetOptions({
    required String troopId,
  }) async {
    final response = await _supabase
        .from('patrols')
        .select('id, name')
        .eq('troop_id', troopId)
        .order('name', ascending: true);

    return (response as List)
        .map((row) {
          final map = Map<String, dynamic>.from(row as Map);
          return NotificationTargetOption(
            id: map['id'] as String,
            label: (map['name'] as String? ?? '').trim(),
          );
        })
        .toList();
  }

  Future<List<NotificationTargetOption>> fetchIndividualTargetOptions({
    required String troopId,
  }) async {
    final response = await _supabase
        .from(_profilesTable)
        .select('id, first_name, middle_name, last_name, phone, signup_troop')
        .eq('approved', true)
        .eq('signup_troop', troopId)
        .order('first_name', ascending: true);

    return (response as List)
        .map((row) {
          final map = Map<String, dynamic>.from(row as Map);
          final first = (map['first_name'] as String? ?? '').trim();
          final middle = (map['middle_name'] as String? ?? '').trim();
          final last = (map['last_name'] as String? ?? '').trim();
          final parts = [first, middle, last].where((part) => part.isNotEmpty);
          final displayName = parts.isNotEmpty ? parts.join(' ') : 'Unknown Member';
          final phone = (map['phone'] as String? ?? '').trim();
          return NotificationTargetOption(
            id: map['id'] as String,
            label: displayName,
            subtitle: phone.isEmpty ? null : phone,
          );
        })
        .toList();
  }

  /// Fetch all available roles that can be targeted for notifications.
  /// Returns role key and display name pairs.
  Future<List<NotificationTargetOption>> fetchRoleTargetOptions() async {
    final response = await _supabase
        .from('roles')
        .select('slug, name, role_rank')
        .order('role_rank', ascending: false);

    return (response as List)
        .map((row) {
          final map = Map<String, dynamic>.from(row as Map);
          return NotificationTargetOption(
            id: (map['slug'] as String? ?? '').trim(),
            label: (map['name'] as String? ?? '').trim(),
          );
        })
        .where((option) => option.id.isNotEmpty && option.label.isNotEmpty)
        .toList();
  }

  Future<int> cleanupSeasonNotifications({required String seasonId}) async {
    final notifications = await _supabase
        .from(_notificationsTable)
        .select('id')
        .eq('season_id', seasonId);

    final notificationIds = (notifications as List)
        .map((row) => (row as Map)['id'] as String?)
        .whereType<String>()
        .toList();

    if (notificationIds.isEmpty) {
      return 0;
    }

    await _supabase
        .from(_recipientsTable)
        .delete()
        .inFilter('notification_id', notificationIds);

    final deletedRows = await _supabase
        .from(_notificationsTable)
        .delete()
        .eq('season_id', seasonId)
        .select('id');

    return (deletedRows as List).length;
  }

  Future<List<String>> _fetchAllApprovedProfileIds() async {
    final response = await _supabase
        .from(_profilesTable)
        .select('id')
        .eq('approved', true);

    return (response as List)
        .map((row) => (row as Map)['id'] as String?)
        .whereType<String>()
        .toList();
  }

  Future<List<String>> _fetchTroopProfileIds(String troopId) async {
    final response = await _supabase
        .from(_profilesTable)
        .select('id')
        .eq('approved', true)
        .eq('signup_troop', troopId);

    return (response as List)
        .map((row) => (row as Map)['id'] as String?)
        .whereType<String>()
        .toList();
  }

  Future<List<String>> _fetchPatrolProfileIds(String patrolId) async {
    final response = await _supabase
        .from(_profilesTable)
        .select('id')
        .eq('approved', true)
        .eq('patrol_id', patrolId);

    return (response as List)
        .map((row) => (row as Map)['id'] as String?)
        .whereType<String>()
        .toList();
  }

  Future<List<String>> _fetchIndividualProfileIds(String profileId) async {
    final response = await _supabase
        .from(_profilesTable)
        .select('id')
        .eq('approved', true)
        .eq('id', profileId);

    return (response as List)
        .map((row) => (row as Map)['id'] as String?)
        .whereType<String>()
        .toList();
  }
  /// Fetch all approved profile IDs associated with a specific role slug.
  /// Role slug is matched against roles.slug.
  /// This joins profiles → profile_roles → roles and returns approved users only.
  Future<List<String>> _fetchRoleProfileIds(String roleSlug) async {
    try {
      // Step 1: Get role ID by slug from roles table
      final roleResponse = await _supabase
          .from('roles')
          .select('id')
          .eq('slug', roleSlug.trim())
          .maybeSingle();

      if (roleResponse == null) {
        return [];
      }

      final roleId = roleResponse['id'] as String?;
      if (roleId == null || roleId.isEmpty) {
        return [];
      }

      // Step 2: Get profile IDs who have this role_id
      final profileRolesResponse = await _supabase
          .from('profile_roles')
          .select('profile_id')
          .eq('role_id', roleId);

      final profileIds = (profileRolesResponse as List)
          .map((row) => (row as Map)['profile_id'] as String?)
          .whereType<String>()
          .toList();

      if (profileIds.isEmpty) {
        return [];
      }

      // Step 3: Filter to only approved profiles
      final approvedProfiles = await _supabase
          .from(_profilesTable)
          .select('id')
          .eq('approved', true)
          .inFilter('id', profileIds);

      return (approvedProfiles as List)
          .map((row) => (row as Map)['id'] as String?)
          .whereType<String>()
          .toList();
    } catch (e) {
      return [];
    }
  }
  void _validateSenderTargetScope({
    required NotificationTargetType targetType,
    required String? targetId,
    required int senderRoleRank,
    required String? senderTroopId,
  }) {
    final isSystemSender = senderRoleRank >= 90;
    final isTroopSender = senderRoleRank == 60 || senderRoleRank == 70;

    if (!isSystemSender && !isTroopSender) {
      throw Exception('You do not have permission to send notifications.');
    }

    if (targetType != NotificationTargetType.all &&
        (targetId == null || targetId.trim().isEmpty)) {
      throw Exception('Please select a valid target.');
    }

    if (isTroopSender && targetType == NotificationTargetType.all) {
      throw Exception('Troop roles cannot send notifications to all users.');
    }

    if (isTroopSender && targetType == NotificationTargetType.role) {
      throw Exception('Troop roles cannot send notifications by role. Only system-wide admins can use role-based targeting.');
    }

    if (isTroopSender && (senderTroopId == null || senderTroopId.trim().isEmpty)) {
      throw Exception('No troop scope is available for this account.');
    }
  }

  Future<bool> validateScopedTarget({
    required NotificationTargetType targetType,
    required String targetId,
    required String senderTroopId,
  }) async {
    switch (targetType) {
      case NotificationTargetType.all:
        return false;
      case NotificationTargetType.troop:
        return targetId == senderTroopId;
      case NotificationTargetType.patrol:
        final patrol = await _supabase
            .from('patrols')
            .select('id')
            .eq('id', targetId)
            .eq('troop_id', senderTroopId)
            .maybeSingle();
        return patrol != null;
      case NotificationTargetType.individual:
        final profile = await _supabase
            .from(_profilesTable)
            .select('id')
            .eq('id', targetId)
            .eq('signup_troop', senderTroopId)
            .eq('approved', true)
            .maybeSingle();
        return profile != null;
      case NotificationTargetType.role:
        return false; // Troop-scoped senders cannot send by role
    }
  }
}
