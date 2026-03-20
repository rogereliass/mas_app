import 'package:flutter_test/flutter_test.dart';
import 'package:masapp/routing/deep_link/deep_link_model.dart';
import 'package:masapp/routing/deep_link/deep_link_parser.dart';

void main() {
  group('DeepLinkParser', () {
    test('parses meeting payload with meeting_id', () {
      final link = DeepLinkParser.parse(
        <String, dynamic>{
          'type': 'meeting',
          'meeting_id': 'abc-123',
        },
      );

      expect(link.type, DeepLinkType.meeting);
      expect(link.isValid, isTrue);
      expect(link.paramAsString('meeting_id'), 'abc-123');
    });

    test('parses attendance payload with normalized keys', () {
      final link = DeepLinkParser.parse(
        <String, dynamic>{
          'TYPE': 'attendance',
          'MEETING_ID': 'meeting_01',
        },
      );

      expect(link.type, DeepLinkType.attendance);
      expect(link.isValid, isTrue);
      expect(link.paramAsString('meeting_id'), 'meeting_01');
    });

    test('returns invalid when attendance payload misses meeting_id', () {
      final link = DeepLinkParser.parse(
        <String, dynamic>{
          'type': 'attendance',
        },
      );

      expect(link.type, DeepLinkType.attendance);
      expect(link.isValid, isFalse);
      expect(link.error, isNotNull);
    });

    test('parses patrol payload and validates patrol_id', () {
      final link = DeepLinkParser.parse(
        <String, dynamic>{
          'type': 'patrol',
          'patrol_id': 'patrol-77',
        },
      );

      expect(link.type, DeepLinkType.patrol);
      expect(link.isValid, isTrue);
      expect(link.paramAsString('patrol_id'), 'patrol-77');
    });

    test('profile payload is valid without profile_id', () {
      final link = DeepLinkParser.parse(
        <String, dynamic>{
          'type': 'profile',
        },
      );

      expect(link.type, DeepLinkType.profile);
      expect(link.isValid, isTrue);
      expect(link.paramAsString('profile_id'), isNull);
    });

    test('unknown type falls back safely', () {
      final link = DeepLinkParser.parse(
        <String, dynamic>{
          'type': 'unexpected_type',
          'x': 1,
        },
      );

      expect(link.type, DeepLinkType.unknown);
      expect(link.isValid, isFalse);
    });

    test('empty payload is ignored safely', () {
      final link = DeepLinkParser.parse(<String, dynamic>{});

      expect(link.type, DeepLinkType.unknown);
      expect(link.isValid, isFalse);
      expect(link.error, isNull);
    });
  });
}
