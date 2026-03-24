import 'deep_link_model.dart';

class DeepLinkParser {
  DeepLinkParser._();

  static final RegExp _safeIdPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  );

  static DeepLinkModel parse(Map<String, dynamic> data) {
    if (data.isEmpty) {
      return const DeepLinkModel(
        type: DeepLinkType.unknown,
        params: <String, dynamic>{},
        isValid: false,
        error: null,
      );
    }

    final normalized = _normalizePayload(data);
    final type = _parseType(_stringValue(normalized['type']));

    switch (type) {
      case DeepLinkType.meeting:
        return _parseMeeting(normalized);
      case DeepLinkType.attendance:
        return _parseAttendance(normalized);
      case DeepLinkType.patrol:
        return _parsePatrol(normalized);
      case DeepLinkType.profile:
        return _parseProfile(normalized);
      case DeepLinkType.unknown:
        return DeepLinkModel(
          type: DeepLinkType.unknown,
          params: normalized,
          isValid: false,
          error: 'Unsupported deep link type.',
        );
    }
  }

  static DeepLinkModel _parseMeeting(Map<String, dynamic> payload) {
    final meetingId = _extractId(payload, keys: const ['meeting_id', 'meetingid']);
    if (meetingId == null) {
      return DeepLinkModel(
        type: DeepLinkType.meeting,
        params: payload,
        isValid: false,
        error: 'Missing or invalid meeting_id.',
      );
    }

    return DeepLinkModel(
      type: DeepLinkType.meeting,
      params: <String, dynamic>{'meeting_id': meetingId},
      isValid: true,
    );
  }

  static DeepLinkModel _parseAttendance(Map<String, dynamic> payload) {
    final meetingId = _extractId(payload, keys: const ['meeting_id', 'meetingid']);
    if (meetingId == null) {
      return DeepLinkModel(
        type: DeepLinkType.attendance,
        params: payload,
        isValid: false,
        error: 'Missing or invalid meeting_id.',
      );
    }

    return DeepLinkModel(
      type: DeepLinkType.attendance,
      params: <String, dynamic>{'meeting_id': meetingId},
      isValid: true,
    );
  }

  static DeepLinkModel _parsePatrol(Map<String, dynamic> payload) {
    final patrolId = _extractId(payload, keys: const ['patrol_id', 'patrolid']);
    if (patrolId == null) {
      return DeepLinkModel(
        type: DeepLinkType.patrol,
        params: payload,
        isValid: false,
        error: 'Missing or invalid patrol_id.',
      );
    }

    return DeepLinkModel(
      type: DeepLinkType.patrol,
      params: <String, dynamic>{'patrol_id': patrolId},
      isValid: true,
    );
  }

  static DeepLinkModel _parseProfile(Map<String, dynamic> payload) {
    final profileId = _extractId(
      payload,
      keys: const ['profile_id', 'profileid'],
      required: false,
    );

    return DeepLinkModel(
      type: DeepLinkType.profile,
      params: <String, dynamic>{
        if (profileId != null) 'profile_id': profileId,
      },
      isValid: true,
    );
  }

  static String? _extractId(
    Map<String, dynamic> payload, {
    required List<String> keys,
    bool required = true,
  }) {
    for (final key in keys) {
      final value = _stringValue(payload[key]);
      if (value == null) {
        continue;
      }
      if (_safeIdPattern.hasMatch(value)) {
        return value;
      }
    }

    if (!required) {
      return null;
    }

    return null;
  }

  static DeepLinkType _parseType(String? value) {
    switch (value) {
      case 'meeting':
        return DeepLinkType.meeting;
      case 'attendance':
        return DeepLinkType.attendance;
      case 'patrol':
        return DeepLinkType.patrol;
      case 'profile':
        return DeepLinkType.profile;
      default:
        return DeepLinkType.unknown;
    }
  }

  static Map<String, dynamic> _normalizePayload(Map<String, dynamic> payload) {
    final normalized = <String, dynamic>{};
    payload.forEach((key, value) {
      normalized[key.toString().trim().toLowerCase()] = value;
    });
    return normalized;
  }

  static String? _stringValue(Object? value) {
    if (value == null) {
      return null;
    }
    final normalized = value.toString().trim();
    return normalized.isEmpty ? null : normalized;
  }
}
