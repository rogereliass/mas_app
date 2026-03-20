import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:masapp/home/pages/notifications/ui/components/notifications_panel.dart';
import 'package:masapp/home/pages/notifications/ui/components/notification_detail_modal.dart';
import 'package:masapp/home/pages/notifications/logic/notifications_provider.dart';
import 'package:masapp/home/pages/notifications/data/models/notification_models.dart';
import 'package:masapp/auth/logic/auth_provider.dart';

class MockNotificationsProvider extends ChangeNotifier implements NotificationsProvider {
  @override
  bool get isLoading => false;
  @override
  bool get isRefreshing => false;
  @override
  bool get isSending => false;
  @override
  String? get error => null;
  @override
  List<NotificationRecipientEntry> get items => [];
  @override
  int get unreadCount => 0;
  @override
  bool get canSendNotifications => true;
  @override
  List<NotificationTargetType> get availableTargetTypes => [NotificationTargetType.all];
  
  @override
  Future<void> loadNotifications({bool forceRefresh = false}) async {}
  @override
  Future<void> refresh() async {}
  @override
  Future<void> markAsRead(String id) async {}
  @override
  Future<void> markAllAsRead() async {}
  @override
  Future<NotificationCreateResult> sendNotification({required NotificationCreateRequest request}) async {
    return const NotificationCreateResult(notificationId: '1', recipientCount: 1);
  }
  @override
  Future<List<NotificationTargetOption>> loadTroopTargets() async => [];
  @override
  Future<List<NotificationTargetOption>> loadPatrolTargets({String? selectedTroopId}) async => [];
  @override
  Future<List<NotificationTargetOption>> loadIndividualTargets({String? selectedTroopId}) async => [];
  @override
  Future<int> cleanupSeasonNotifications(String seasonId) async => 0;
}

class MockAuthProvider extends ChangeNotifier implements AuthProvider {
  @override
  int get selectedRoleRank => 100;
  @override
  bool get profileLoading => false;
  @override
  dynamic get currentUserProfile => null;
  // Add other required overrides if necessary, or use a simpler approach
}

void main() {
  testWidgets('NotificationDetailModal handles long content without overflow', (WidgetTester tester) async {
    final entry = NotificationRecipientEntry(
      id: '1',
      profileId: 'u1',
      notificationId: 'n1',
      isRead: false,
      createdAt: DateTime.now(),
      notification: NotificationEntry(
        id: 'n1',
        title: 'Very ' * 50 + 'Long Title',
        body: 'Very ' * 100 + 'Long Body Content that should wrap properly in the modal view.',
        type: NotificationType.announcement,
        senderId: 's1',
        createdAt: DateTime.now(),
        data: {},
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(
          body: NotificationDetailModal(
            entry: entry,
            onMarkRead: () async {},
          ),
        ),
      ),
    );

    // Verify title and body are rendered
    expect(find.textContaining('Long Title'), findsOneWidget);
    
    // Check for overflows
    expect(tester.takeException(), isNull);
  });

  testWidgets('NotificationsPanel builds without overflow', (WidgetTester tester) async {
    final mockNotifications = MockNotificationsProvider();
    final mockAuth = MockAuthProvider();

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider<NotificationsProvider>.value(value: mockNotifications),
            ChangeNotifierProvider<AuthProvider>.value(value: mockAuth),
          ],
          child: const Scaffold(body: NotificationsPanel()),
        ),
      ),
    );

    expect(find.text('Notifications'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
