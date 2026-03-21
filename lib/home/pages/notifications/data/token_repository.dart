import 'package:supabase_flutter/supabase_flutter.dart';

class TokenRepository {
  TokenRepository({SupabaseClient? supabaseClient})
      : _supabase = supabaseClient ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  Future<void> upsertDeviceToken({
    required String profileId,
    required String fcmToken,
    required String deviceType,
  }) async {
    final normalizedProfileId = profileId.trim();
    final normalizedToken = fcmToken.trim();
    final normalizedDeviceType = deviceType.trim().toLowerCase();

    if (normalizedProfileId.isEmpty || normalizedToken.isEmpty) {
      return;
    }

    await _supabase.rpc(
      'upsert_device_token',
      params: {
        'p_profile_id': normalizedProfileId,
        'p_fcm_token': normalizedToken,
        'p_device_type': normalizedDeviceType,
      },
    );
  }

  Future<void> deactivateDeviceToken(String fcmToken) async {
    final normalizedToken = fcmToken.trim();
    if (normalizedToken.isEmpty) {
      return;
    }

    await _supabase.rpc(
      'deactivate_device_token',
      params: {
        'p_fcm_token': normalizedToken,
      },
    );
  }
}
