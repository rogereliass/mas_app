import 'package:flutter_test/flutter_test.dart';
import 'package:masapp/auth/models/user_profile.dart';
import 'package:masapp/home/pages/notifications/data/models/notification_models.dart';
import 'package:masapp/home/pages/notifications/data/notification_action_service.dart';

void main() {
  group('NotificationActionService', () {
    late NotificationCreateRequest? lastRequest;
    late UserProfile? lastSender;
    late int? lastSenderRank;
    late NotificationActionService service;

    setUp(() {
      lastRequest = null;
      lastSender = null;
      lastSenderRank = null;

      final currentProfile = UserProfile(
        id: 'profile-1',
        userId: 'auth-user-1',
        roleRank: 90,
        createdAt: DateTime(2026, 1, 1),
      );

      service = NotificationActionService(
        currentUserProfileLoader: () async => currentProfile,
        sendNotification: ({
          required UserProfile senderProfile,
          required int senderRoleRank,
          required NotificationCreateRequest request,
        }) async {
          lastSender = senderProfile;
          lastSenderRank = senderRoleRank;
          lastRequest = request;

          return const NotificationCreateResult(
            notificationId: 'notification-1',
            recipientCount: 1,
          );
        },
      );
    });

    test('sendToAll forwards all target type', () async {
      final result = await service.sendToAll(
        title: 'Hello',
        body: 'World',
        type: 'announcement',
      );

      expect(result.recipientCount, 1);
      expect(lastRequest?.targetType, NotificationTargetType.all);
      expect(lastRequest?.targetId, isNull);
      expect(lastSender?.id, 'profile-1');
      expect(lastSenderRank, 90);
    });

    test('sendToRole forwards normalized role and optional troop scope', () async {
      await service.sendToRole(
        roleName: 'Troop Leader',
        troopId: 'troop-1',
        title: 'Title',
        body: 'Body',
        type: 'meeting',
      );

      expect(lastRequest?.targetType, NotificationTargetType.role);
      expect(lastRequest?.targetId, 'troop_leader');
      expect(lastRequest?.roleTroopId, 'troop-1');
    });

    test('sendToTroop validates troop id', () async {
      expect(
        () => service.sendToTroop(
          troopId: '   ',
          title: 'Title',
          body: 'Body',
          type: 'meeting',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws on unsupported notification type', () async {
      expect(
        () => service.sendToUser(
          profileId: 'profile-1',
          title: 'Title',
          body: 'Body',
          type: 'unsupported_type',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
