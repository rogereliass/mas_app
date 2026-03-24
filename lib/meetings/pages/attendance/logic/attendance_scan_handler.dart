import 'package:flutter/foundation.dart';

import 'package:masapp/meetings/pages/attendance/logic/attendance_provider.dart';

enum AttendanceScanFeedbackType {
  success,
  alreadyMarked,
  invalidCode,
  unauthorized,
  notInContext,
  error,
}

class AttendanceScanFeedback {
  const AttendanceScanFeedback({
    required this.type,
    required this.message,
    this.memberName,
  });

  final AttendanceScanFeedbackType type;
  final String message;
  final String? memberName;
}

/// Handles QR parsing, duplicate throttling, and attendance scan outcomes.
class AttendanceScanHandler {
  AttendanceScanHandler({
    required AttendanceProvider attendanceProvider,
    this.duplicateCooldown = const Duration(seconds: 3),
  }) : _attendanceProvider = attendanceProvider;

  final AttendanceProvider _attendanceProvider;
  final Duration duplicateCooldown;

  final Map<String, DateTime> _recentScans = <String, DateTime>{};
  bool _isProcessing = false;

  static final RegExp _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}\-[0-9a-fA-F]{4}\-[1-5][0-9a-fA-F]{3}\-[89abAB][0-9a-fA-F]{3}\-[0-9a-fA-F]{12}$',
  );

  Future<AttendanceScanFeedback?> handleRawCode(String rawCode) async {
    final parsedProfileId = _extractProfileId(rawCode);
    if (parsedProfileId == null) {
      return const AttendanceScanFeedback(
        type: AttendanceScanFeedbackType.invalidCode,
        message: 'Invalid QR code',
      );
    }

    if (_isWithinCooldown(parsedProfileId)) {
      return null;
    }

    if (_isProcessing) {
      return null;
    }

    _isProcessing = true;
    _markScannedNow(parsedProfileId);

    try {
      final result = await _attendanceProvider.markPresentFromScan(
        parsedProfileId,
      );
      return _toFeedback(result);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AttendanceScanHandler.handleRawCode error: $e');
      }
      return const AttendanceScanFeedback(
        type: AttendanceScanFeedbackType.error,
        message: 'Unexpected scan error. Please try again.',
      );
    } finally {
      _isProcessing = false;
    }
  }

  void dispose() {
    _recentScans.clear();
  }

  String? _extractProfileId(String rawCode) {
    final value = rawCode.trim();
    if (value.isEmpty) {
      return null;
    }

    if (_uuidPattern.hasMatch(value)) {
      return value.toLowerCase();
    }

    if (value.toLowerCase().startsWith('user:')) {
      final candidate = value.substring(5).trim();
      if (_uuidPattern.hasMatch(candidate)) {
        return candidate.toLowerCase();
      }
    }

    return null;
  }

  bool _isWithinCooldown(String profileId) {
    final now = DateTime.now();
    final lastScanAt = _recentScans[profileId];
    if (lastScanAt == null) {
      return false;
    }

    return now.difference(lastScanAt) < duplicateCooldown;
  }

  void _markScannedNow(String profileId) {
    final now = DateTime.now();
    _recentScans[profileId] = now;

    // Keep memory bounded while preserving recent-window dedup.
    _recentScans.removeWhere(
      (_, timestamp) => now.difference(timestamp) > duplicateCooldown * 4,
    );
  }

  AttendanceScanFeedback _toFeedback(AttendanceScanMarkResult result) {
    switch (result.type) {
      case AttendanceScanMarkResultType.markedPresent:
        return AttendanceScanFeedback(
          type: AttendanceScanFeedbackType.success,
          message: 'Marked Present: ${result.memberName ?? 'Member'}',
          memberName: result.memberName,
        );
      case AttendanceScanMarkResultType.alreadyPresent:
        return const AttendanceScanFeedback(
          type: AttendanceScanFeedbackType.alreadyMarked,
          message: 'Already marked present',
        );
      case AttendanceScanMarkResultType.invalidContext:
        return const AttendanceScanFeedback(
          type: AttendanceScanFeedbackType.notInContext,
          message: 'Member does not belong to this meeting context',
        );
      case AttendanceScanMarkResultType.unauthorized:
        return const AttendanceScanFeedback(
          type: AttendanceScanFeedbackType.unauthorized,
          message: 'You are not allowed to scan attendance',
        );
      case AttendanceScanMarkResultType.error:
        return AttendanceScanFeedback(
          type: AttendanceScanFeedbackType.error,
          message: result.errorMessage ?? 'Failed to mark attendance',
        );
    }
  }
}
