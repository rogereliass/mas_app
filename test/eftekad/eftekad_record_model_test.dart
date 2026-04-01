import 'package:flutter_test/flutter_test.dart';
import 'package:masapp/home/pages/eftekad/data/models/eftekad_record.dart';

void main() {
  group('EftekadRecord', () {
    test('serializes to insert payload and parses queue payload', () {
      final createdAt = DateTime.utc(2026, 4, 1, 9, 30);
      final nextFollowUpDate = DateTime.utc(2026, 4, 12, 10, 0);

      final record = EftekadRecord(
        id: 'record-id',
        profileId: 'profile-id',
        createdByProfileId: 'creator-id',
        createdAt: createdAt,
        type: EftekadRecordType.inPerson,
        reason: 'Follow-up reason',
        notes: 'Follow-up notes',
        outcome: 'Outcome text',
        nextFollowUpDate: nextFollowUpDate,
      );

      final insert = record.toInsertJson();
      expect(insert['id'], 'record-id');
      expect(insert['profile_id'], 'profile-id');
      expect(insert['created_by_profile_id'], 'creator-id');
      expect(insert['type'], 'in_person');
      expect(insert['reason'], 'Follow-up reason');
      expect(insert['notes'], 'Follow-up notes');
      expect(insert['outcome'], 'Outcome text');
      expect(insert['next_follow_up_date'], nextFollowUpDate.toIso8601String());

      final queue = record.toQueuePayload();
      final hydrated = EftekadRecord.fromQueuePayload(queue);
      expect(hydrated.id, record.id);
      expect(hydrated.profileId, record.profileId);
      expect(hydrated.createdByProfileId, record.createdByProfileId);
      expect(hydrated.type, EftekadRecordType.inPerson);
      expect(hydrated.reason, record.reason);
      expect(hydrated.notes, record.notes);
      expect(hydrated.outcome, record.outcome);
      expect(hydrated.nextFollowUpDate, nextFollowUpDate);
    });

    test('maps db type values to enum safely', () {
      expect(EftekadRecordTypeX.fromDbValue('call'), EftekadRecordType.call);
      expect(
        EftekadRecordTypeX.fromDbValue('in_person'),
        EftekadRecordType.inPerson,
      );
      expect(
        EftekadRecordTypeX.fromDbValue('message'),
        EftekadRecordType.message,
      );
      expect(EftekadRecordTypeX.fromDbValue('other'), EftekadRecordType.other);
      expect(
        EftekadRecordTypeX.fromDbValue('unknown'),
        EftekadRecordType.other,
      );
    });
  });
}
