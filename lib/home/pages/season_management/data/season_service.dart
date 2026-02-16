import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/data/scoped_service_mixin.dart';
import 'models/season.dart';

/// Season Management Service
///
/// Handles CRUD operations for seasons
class SeasonService with ScopedServiceMixin {
  static const String _seasonsTable = 'seasons';

  final SupabaseClient _supabase;

  SeasonService(this._supabase);

  factory SeasonService.instance() {
    return SeasonService(Supabase.instance.client);
  }

  /// Fetch all seasons ordered by start date (descending)
  Future<List<Season>> fetchSeasons() async {
    try {
      final response = await _supabase
          .from(_seasonsTable)
          .select()
          .order('start_date', ascending: false);

      return (response as List)
          .map((json) => Season.fromJson(json))
          .toList();
    } catch (e) {
      _logError('fetchSeasons', e);
      rethrow;
    }
  }

  /// Create a new season
  Future<Season> createSeason(Season season) async {
    try {
      final response = await _supabase
          .from(_seasonsTable)
          .insert(season.toJson())
          .select()
          .single();

      return Season.fromJson(response);
    } catch (e) {
      _logError('createSeason', e);
      rethrow;
    }
  }

  /// Check if a season code already exists
  Future<bool> checkSeasonCodeExists(String code) async {
    try {
      final response = await _supabase
          .from(_seasonsTable)
          .select('id')
          .eq('season_code', code)
          .maybeSingle();
      
      return response != null;
    } catch (e) {
      _logError('checkSeasonCodeExists', e);
      rethrow;
    }
  }

  void _logError(String operation, Object error) {
    debugPrint('❌ SeasonService.$operation error: $error');
  }
}
