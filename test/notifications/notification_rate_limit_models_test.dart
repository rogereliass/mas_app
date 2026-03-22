import 'package:flutter_test/flutter_test.dart';
import 'package:masapp/home/pages/notifications/data/models/notification_models.dart';

void main() {
  group('NotificationSendRateLimitResult', () {
    test('parses cooldown payload', () {
      final result = NotificationSendRateLimitResult.fromJson(
        <String, dynamic>{
          'allowed': false,
          'reason': 'cooldown',
          'retry_after_seconds': 87,
          'remaining_quota': 7,
          'window_reset_at': '2026-03-22T12:00:00Z',
        },
      );

      expect(result.allowed, isFalse);
      expect(result.reason, 'cooldown');
      expect(result.retryAfterSeconds, 87);
      expect(result.remainingQuota, 7);
      expect(result.windowResetAt, isNotNull);
    });

    test('normalizes missing fields safely', () {
      final result = NotificationSendRateLimitResult.fromJson(
        <String, dynamic>{
          'allowed': true,
        },
      );

      expect(result.allowed, isTrue);
      expect(result.reason, 'unknown');
      expect(result.retryAfterSeconds, 0);
      expect(result.remainingQuota, isNull);
      expect(result.windowResetAt, isNull);
    });
  });

  group('NotificationSendRateLimitException', () {
    test('includes reason in toString', () {
      final details = NotificationSendRateLimitResult.fromJson(
        <String, dynamic>{
          'allowed': false,
          'reason': 'daily_quota',
          'retry_after_seconds': 600,
        },
      );

      final exception = NotificationSendRateLimitException(details);
      expect(exception.toString(), contains('daily_quota'));
    });
  });
}
