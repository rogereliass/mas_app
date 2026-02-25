import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:masapp/meetings/pages/meeting_creation/data/models/meeting.dart';

/// Service responsible for all Supabase operations related to meetings.
class MeetingsService {
  final SupabaseClient _supabase;

  MeetingsService(this._supabase);

  factory MeetingsService.instance() {
    return MeetingsService(Supabase.instance.client);
  }

  // -------------------------------------------------------------------------
  // Seasons
  // -------------------------------------------------------------------------

  /// Returns the currently active season (where today falls between
  /// `start_date` and `end_date`), or `null` if none is found.
  Future<Map<String, dynamic>?> fetchActiveSeason() async {
    try {
      final today = DateTime.now().toIso8601String().substring(0, 10);

      final result = await _supabase
          .from('seasons')
          .select()
          .lte('start_date', today)
          .gte('end_date', today)
          .limit(1)
          .maybeSingle();

      return result;
    } catch (e) {
      throw Exception('MeetingsService.fetchActiveSeason: $e');
    }
  }

  // -------------------------------------------------------------------------
  // Troops
  // -------------------------------------------------------------------------

  /// Returns a list of troops as `[{id, name}]`, ordered by name.
  Future<List<Map<String, dynamic>>> fetchTroops() async {
    try {
      final results = await _supabase
          .from('troops')
          .select('id, name')
          .order('name', ascending: true);

      return List<Map<String, dynamic>>.from(results as List);
    } catch (e) {
      throw Exception('MeetingsService.fetchTroops: $e');
    }
  }

  // -------------------------------------------------------------------------
  // Meetings
  // -------------------------------------------------------------------------

  /// Returns all meetings for the given [seasonId] and [troopId],
  /// ordered by `meeting_date ASC`.
  ///
  /// TODO: Implement clan-based meeting support
  Future<List<Meeting>> fetchMeetings({
    required String seasonId,
    required String troopId,
  }) async {
    try {
      final results = await _supabase
          .from('meetings')
          .select()
          // TODO: Implement clan-based meeting support
          .eq('season_id', seasonId)
          .eq('troop_id', troopId)
          .order('meeting_date', ascending: true);

      return (results as List)
          .map((row) => Meeting.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('MeetingsService.fetchMeetings: $e');
    }
  }

  /// Inserts a new meeting row and returns the created [Meeting].
  ///
  /// TODO: Implement clan-based meeting support
  Future<Meeting> createMeeting({
    required String troopId,
    required String seasonId,
    required String createdByProfileId,
    required String title,
    required String location,
    required DateTime meetingDate,
    required DateTime startsAt,
    required DateTime endsAt,
    String? description,
  }) async {
    try {
      final payload = <String, dynamic>{
        // TODO: Implement clan-based meeting support
        'troop_id': troopId,
        'season_id': seasonId,
        'created_by_profile_id': createdByProfileId,
        'title': title,
        'location': location,
        'meeting_date': meetingDate.toIso8601String().substring(0, 10),
        'starts_at': startsAt.toIso8601String(),
        'ends_at': endsAt.toIso8601String(),
        if (description != null) 'description': description,
      };

      final result = await _supabase
          .from('meetings')
          .insert(payload)
          .select()
          .single();

      return Meeting.fromJson(result);
    } catch (e) {
      throw Exception('MeetingsService.createMeeting: $e');
    }
  }
}
