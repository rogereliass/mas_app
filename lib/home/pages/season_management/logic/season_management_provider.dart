import 'package:flutter/foundation.dart';
import '../data/models/season.dart';
import '../data/season_service.dart';

/// Provider for season management operations
class SeasonManagementProvider with ChangeNotifier {
  final SeasonService _service;

  SeasonManagementProvider({SeasonService? service})
      : _service = service ?? SeasonService.instance();

  List<Season> _seasons = [];
  bool _isLoading = false;
  bool _isProcessing = false;
  String? _error;

  List<Season> get seasons => _seasons;
  bool get isLoading => _isLoading;
  bool get isProcessing => _isProcessing;
  bool get hasError => _error != null;
  String? get error => _error;

  /// Load all seasons
  Future<void> loadSeasons() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _seasons = await _service.fetchSeasons();
    } catch (e) {
      _error = 'Failed to load seasons. Please try again.';
      debugPrint('❌ SeasonManagementProvider.loadSeasons error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Create a new season
  Future<bool> createSeason({
    required String year,
    required String seasonType,
    String? name,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    _isProcessing = true;
    _error = null;
    notifyListeners();

    try {
      // Generate season code: Year-SeasonType (e.g. 2026-F)
      final seasonCode = '$year-$seasonType';

      // Validation: Check if season code already exists
      final exists = await _service.checkSeasonCodeExists(seasonCode);
      if (exists) {
        _error = 'Season code $seasonCode already exists.';
        return false;
      }

      final newSeason = Season(
        id: '', // Supabase generates UUID
        seasonCode: seasonCode,
        name: name?.isEmpty == true ? null : name,
        startDate: startDate,
        endDate: endDate,
        createdAt: DateTime.now(),
      );

      final created = await _service.createSeason(newSeason);
      _seasons.insert(0, created); // Add to local list at the top
      return true;
    } catch (e) {
      _error = 'Failed to create season. Please try again.';
      debugPrint('❌ SeasonManagementProvider.createSeason error: $e');
      return false;
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    await loadSeasons();
  }
}
