import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masapp/auth/models/user_profile.dart';
import 'package:masapp/routing/navigation_service.dart';
import 'package:masapp/routing/deep_link/deep_link_handler.dart';
import 'package:masapp/routing/deep_link/deep_link_model.dart';

UserProfile _profileWithRank(int rank) {
  return UserProfile(
    id: 'profile-id',
    userId: 'user-id',
    roleRank: rank,
    createdAt: DateTime.utc(2026, 1, 1),
  );
}

Future<void> _pumpNavigatorHost(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: NavigationService.navigatorKey,
      home: const Scaffold(body: SizedBox.shrink()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('DeepLinkHandler security gating', () {
    testWidgets('blocks meeting management deep link for low-rank user', (
      tester,
    ) async {
      await _pumpNavigatorHost(tester);

      final handler = DeepLinkHandler(
        currentUserProfileLoader: () async => _profileWithRank(50),
      );

      final result = await handler.handle(
        const DeepLinkModel(
          type: DeepLinkType.meeting,
          params: {'meeting_id': '123e4567-e89b-42d3-a456-426614174000'},
          isValid: true,
        ),
      );

      expect(result.handled, isFalse);
      expect(result.message, contains('not allowed'));
    });

    testWidgets('blocks attendance deep link when not authenticated', (
      tester,
    ) async {
      await _pumpNavigatorHost(tester);

      final handler = DeepLinkHandler(
        currentUserProfileLoader: () async => null,
      );

      final result = await handler.handle(
        const DeepLinkModel(
          type: DeepLinkType.attendance,
          params: {'meeting_id': '123e4567-e89b-42d3-a456-426614174001'},
          isValid: true,
        ),
      );

      expect(result.handled, isFalse);
      expect(result.message, contains('Please sign in'));
    });

    testWidgets('blocks patrol deep link for low-rank user', (tester) async {
      await _pumpNavigatorHost(tester);

      final handler = DeepLinkHandler(
        currentUserProfileLoader: () async => _profileWithRank(30),
      );

      final result = await handler.handle(
        const DeepLinkModel(
          type: DeepLinkType.patrol,
          params: {'patrol_id': '123e4567-e89b-42d3-a456-426614174002'},
          isValid: true,
        ),
      );

      expect(result.handled, isFalse);
      expect(result.message, contains('not allowed'));
    });
  });
}
