import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/cache_ttl.dart';
import '../../../../core/utils/ttl_cache.dart';
import 'models/notification_audit_models.dart';
import 'models/notification_models.dart';

class NotificationAuditService {
  NotificationAuditService(this._supabase);

  final SupabaseClient _supabase;

  static final TtlCache<String, List<NotificationAuditEntry>> _auditCache =
      TtlCache<String, List<NotificationAuditEntry>>();

  factory NotificationAuditService.instance() {
    return NotificationAuditService(Supabase.instance.client);
  }

  Future<List<NotificationAuditEntry>> fetchAuditEntries({
    int limit = 80,
    NotificationType? type,
    NotificationTargetType? targetType,
    String? troopId,
    bool forceRefresh = false,
  }) async {
    final typeKey = type?.value ?? 'all';
    final targetTypeKey = targetType?.value ?? 'all';
    final troopIdKey = troopId ?? 'all';
    final cacheKey = 'audit:$typeKey:$targetTypeKey:$troopIdKey:$limit';

    if (!forceRefresh) {
      final cached = _auditCache.get(cacheKey);
      if (cached != null) {
        return cached;
      }
    } else {
      _auditCache.invalidate(cacheKey);
    }

    dynamic query = _supabase
        .from('notifications')
        .select('''
          id,
          type,
          title,
          body,
          data,
          created_at,
          created_by_profile_id,
          target_type,
          target_id,
          creator:profiles!notifications_created_by_profile_id_fkey(
            id,
            first_name,
            middle_name,
            last_name
          ),
          notification_recipients(count)
        ''')
        .order('created_at', ascending: false)
        .limit(limit * 4);

    if (type != null) {
      query = query.eq('type', type.value);
    }

    if (troopId != null && troopId.isNotEmpty) {
      if (targetType == NotificationTargetType.troop) {
        query = query.eq('target_id', troopId).eq('target_type', 'troop');
      } else if (targetType == NotificationTargetType.patrol) {
        final patrolIds = await _fetchPatrolIdsForTroop(troopId);
        if (patrolIds.isEmpty) return const [];
        query = query.inFilter('target_id', patrolIds).eq('target_type', 'patrol');
      } else if (targetType == NotificationTargetType.individual) {
        final profileIds = await _fetchProfileIdsForTroop(troopId);
        if (profileIds.isEmpty) return const [];
        query = query.inFilter('target_id', profileIds).eq('target_type', 'individual');
      }
    } else if (targetType != null) {
      query = query.eq('target_type', targetType.value);
    }

    final response = await query;
    var rows = (response as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();

    // Enforce filters in-memory as a final guard so UI filter state always matches results.
    if (type != null) {
      rows = rows
          .where(
            (row) =>
                NotificationTypeX.fromValue(row['type'] as String?) == type,
          )
          .toList();
    }

    if (targetType != null) {
      rows = rows
          .where(
            (row) =>
                NotificationTargetTypeX.fromValue(
                  row['target_type'] as String?,
                ) ==
                targetType,
          )
          .toList();
    }

    if (troopId != null && troopId.isNotEmpty) {
      final patrolIds = Set<String>.from(await _fetchPatrolIdsForTroop(troopId));
      final profileIds = Set<String>.from(await _fetchProfileIdsForTroop(troopId));

      rows = rows.where((row) {
        final rowTargetType = NotificationTargetTypeX.fromValue(
          row['target_type'] as String?,
        );
        final rowTargetId = (row['target_id'] as String?)?.trim();

        if (rowTargetId == null || rowTargetId.isEmpty) {
          return false;
        }

        switch (rowTargetType) {
          case NotificationTargetType.all:
            return false;
          case NotificationTargetType.troop:
            return rowTargetId == troopId;
          case NotificationTargetType.patrol:
            return patrolIds.contains(rowTargetId);
          case NotificationTargetType.individual:
            return profileIds.contains(rowTargetId);
        }
      }).toList();
    }

    if (rows.length > limit) {
      rows = rows.take(limit).toList();
    }

    final targetIdsByType = _collectTargetIds(rows);
    final troopLabels = await _fetchTroopLabels(targetIdsByType['troop']!);
    final patrolLabels = await _fetchPatrolLabels(targetIdsByType['patrol']!);
    final profileLabels = await _fetchProfileLabels(targetIdsByType['individual']!);

    final entries = rows.map((row) {
      final targetType = NotificationTargetTypeX.fromValue(
        row['target_type'] as String?,
      );
      final targetId = row['target_id'] as String?;
      final creator = row['creator'];
      final senderName = _buildProfileName(creator);
      final type = NotificationTypeX.fromValue(row['type'] as String?);
      final recipientCount = _parseRecipientCount(row['notification_recipients']);
      final dataRaw = row['data'];

      String? targetLabel;
      if (targetType == NotificationTargetType.troop) {
        targetLabel = troopLabels[targetId];
      } else if (targetType == NotificationTargetType.patrol) {
        targetLabel = patrolLabels[targetId];
      } else if (targetType == NotificationTargetType.individual) {
        targetLabel = profileLabels[targetId];
      }

      return NotificationAuditEntry(
        id: row['id'] as String? ?? '',
        title: (row['title'] as String? ?? '').trim(),
        body: (row['body'] as String? ?? '').trim(),
        type: type,
        createdAt:
            DateTime.tryParse(row['created_at'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        createdByProfileId: row['created_by_profile_id'] as String?,
        senderName: senderName,
        targetType: targetType,
        targetId: targetId,
        targetLabel: targetLabel,
        recipientCount: recipientCount,
        data: dataRaw is Map<String, dynamic>
            ? dataRaw
            : dataRaw is Map
                ? Map<String, dynamic>.from(dataRaw)
                : <String, dynamic>{},
      );
    }).toList();

    _auditCache.set(cacheKey, entries, CacheTtl.notificationsList);
    return entries;
  }

  void clearAuditCache() {
    _auditCache.clear();
  }

  Future<List<NotificationTargetOption>> fetchFilterTroops() async {
    try {
      final response = await _supabase
          .from('troops')
          .select('id, name')
          .order('name');

      final options = (response as List)
          .map((row) {
            final typed = Map<String, dynamic>.from(row as Map);
            final id = (typed['id'] as String? ?? '').trim();
            final name = (typed['name'] as String? ?? '').trim();
            if (id.isEmpty || name.isEmpty) {
              return null;
            }
            return NotificationTargetOption(id: id, label: name);
          })
          .whereType<NotificationTargetOption>()
          .toList();

      if (options.isNotEmpty) {
        return options;
      }
    } catch (_) {
      // Fall through to notifications-derived fallback.
    }

    final notifications = await _supabase
        .from('notifications')
        .select('target_id')
        .eq('target_type', 'troop')
        .not('target_id', 'is', null)
        .order('target_id', ascending: true)
        .limit(2000);

    final troopIds = <String>{};
    for (final row in notifications as List) {
      final typed = Map<String, dynamic>.from(row as Map);
      final id = (typed['target_id'] as String? ?? '').trim();
      if (id.isNotEmpty) {
        troopIds.add(id);
      }
    }

    return troopIds
        .map(
          (id) => NotificationTargetOption(
            id: id,
            label: 'Troop $id',
          ),
        )
        .toList();
  }

  Future<List<String>> _fetchPatrolIdsForTroop(String troopId) async {
    final response = await _supabase
        .from('patrols')
        .select('id')
        .eq('troop_id', troopId);
    return (response as List).map((r) => (r as Map)['id'] as String).toList();
  }

  Future<List<String>> _fetchProfileIdsForTroop(String troopId) async {
    final response = await _supabase
        .from('profiles')
        .select('id')
        .eq('signup_troop', troopId);
    return (response as List).map((r) => (r as Map)['id'] as String).toList();
  }

  Map<String, Set<String>> _collectTargetIds(List<Map<String, dynamic>> rows) {
    final troopIds = <String>{};
    final patrolIds = <String>{};
    final profileIds = <String>{};

    for (final row in rows) {
      final targetType = NotificationTargetTypeX.fromValue(
        row['target_type'] as String?,
      );
      final targetId = (row['target_id'] as String?)?.trim();
      if (targetId == null || targetId.isEmpty) {
        continue;
      }

      if (targetType == NotificationTargetType.troop) {
        troopIds.add(targetId);
      } else if (targetType == NotificationTargetType.patrol) {
        patrolIds.add(targetId);
      } else if (targetType == NotificationTargetType.individual) {
        profileIds.add(targetId);
      }
    }

    return <String, Set<String>>{
      'troop': troopIds,
      'patrol': patrolIds,
      'individual': profileIds,
    };
  }

  Future<Map<String, String>> _fetchTroopLabels(Set<String> troopIds) async {
    if (troopIds.isEmpty) {
      return <String, String>{};
    }

    final response = await _supabase
        .from('troops')
        .select('id, name')
        .inFilter('id', troopIds.toList());

    final map = <String, String>{};
    for (final row in response as List) {
      final typed = Map<String, dynamic>.from(row as Map);
      final id = typed['id'] as String?;
      final name = (typed['name'] as String? ?? '').trim();
      if (id != null && name.isNotEmpty) {
        map[id] = name;
      }
    }
    return map;
  }

  Future<Map<String, String>> _fetchPatrolLabels(Set<String> patrolIds) async {
    if (patrolIds.isEmpty) {
      return <String, String>{};
    }

    final response = await _supabase
        .from('patrols')
        .select('id, name')
        .inFilter('id', patrolIds.toList());

    final map = <String, String>{};
    for (final row in response as List) {
      final typed = Map<String, dynamic>.from(row as Map);
      final id = typed['id'] as String?;
      final name = (typed['name'] as String? ?? '').trim();
      if (id != null && name.isNotEmpty) {
        map[id] = name;
      }
    }
    return map;
  }

  Future<Map<String, String>> _fetchProfileLabels(Set<String> profileIds) async {
    if (profileIds.isEmpty) {
      return <String, String>{};
    }

    final response = await _supabase
        .from('profiles')
        .select('id, first_name, middle_name, last_name')
        .inFilter('id', profileIds.toList());

    final map = <String, String>{};
    for (final row in response as List) {
      final typed = Map<String, dynamic>.from(row as Map);
      final id = typed['id'] as String?;
      if (id == null) {
        continue;
      }
      final label = _buildProfileName(typed);
      map[id] = label ?? 'Unknown Member';
    }
    return map;
  }

  int _parseRecipientCount(dynamic raw) {
    if (raw is List && raw.isNotEmpty) {
      final item = raw.first;
      if (item is Map<String, dynamic>) {
        return item['count'] as int? ?? 0;
      }
      if (item is Map) {
        return item['count'] as int? ?? 0;
      }
    }
    return 0;
  }

  String? _buildProfileName(dynamic profileRaw) {
    if (profileRaw == null) {
      return null;
    }

    Map<String, dynamic> profile;
    if (profileRaw is Map<String, dynamic>) {
      profile = profileRaw;
    } else if (profileRaw is Map) {
      profile = Map<String, dynamic>.from(profileRaw);
    } else {
      return null;
    }

    final first = (profile['first_name'] as String? ?? '').trim();
    final middle = (profile['middle_name'] as String? ?? '').trim();
    final last = (profile['last_name'] as String? ?? '').trim();

    final parts = [first, middle, last].where((part) => part.isNotEmpty);
    if (parts.isEmpty) {
      return null;
    }
    return parts.join(' ');
  }
}
