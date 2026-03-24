import 'package:flutter/foundation.dart';

import '../../auth/data/role_repository.dart';
import '../../auth/models/user_profile.dart';
import '../app_router.dart';
import '../navigation_service.dart';
import 'deep_link_model.dart';

class DeepLinkHandler {
  DeepLinkHandler({
    RoleRepository? roleRepository,
    Future<UserProfile?> Function()? currentUserProfileLoader,
  }) : _roleRepository = roleRepository,
       _currentUserProfileLoader = currentUserProfileLoader;

  RoleRepository? _roleRepository;
  final Future<UserProfile?> Function()? _currentUserProfileLoader;

  Future<UserProfile?> _getCurrentUserProfile() {
    final loader = _currentUserProfileLoader;
    if (loader != null) {
      return loader();
    }
    _roleRepository ??= RoleRepository();
    return _roleRepository!.getCurrentUserProfile();
  }

  Future<DeepLinkHandleResult> handle(DeepLinkModel link) async {
    if (!link.isValid) {
      return DeepLinkHandleResult(
        handled: false,
        message: link.error,
      );
    }

    final hasNavigator = NavigationService.navigator != null;
    if (!hasNavigator) {
      return const DeepLinkHandleResult(
        handled: false,
        message: 'Navigation is not ready yet. Please try again.',
      );
    }

    try {
      switch (link.type) {
        case DeepLinkType.meeting:
          return _openMeetingsManagement(link);
        case DeepLinkType.attendance:
          return _openMeetingsAttendance(link);
        case DeepLinkType.patrol:
          return _openPatrols();
        case DeepLinkType.profile:
          return _openProfile();
        case DeepLinkType.unknown:
          return const DeepLinkHandleResult(
            handled: false,
            message: 'Unsupported deep link type.',
          );
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('DeepLinkHandler.handle error: $e\n$st');
      }
      return const DeepLinkHandleResult(
        handled: false,
        message: 'Could not open this link right now. Please try again.',
      );
    }
  }

  Future<DeepLinkHandleResult> _openMeetingsManagement(DeepLinkModel link) async {
    final profile = await _getCurrentUserProfile();
    if (profile == null) {
      return const DeepLinkHandleResult(
        handled: false,
        message: 'Please sign in to open this notification.',
      );
    }

    if (profile.roleRank < 60) {
      return const DeepLinkHandleResult(
        handled: false,
        message: 'You are not allowed to open meeting management.',
      );
    }

    await NavigationService.pushNamedAndRemoveUntil(
      AppRouter.meetings,
      arguments: MeetingsRouteArgs(
        initialTabIndex: MeetingsTab.management,
        meetingId: link.paramAsString('meeting_id'),
      ),
    );

    return const DeepLinkHandleResult(handled: true);
  }

  Future<DeepLinkHandleResult> _openMeetingsAttendance(DeepLinkModel link) async {
    if (!await _isAuthenticated()) {
      return const DeepLinkHandleResult(
        handled: false,
        message: 'Please sign in to open this notification.',
      );
    }

    await NavigationService.pushNamedAndRemoveUntil(
      AppRouter.meetings,
      arguments: MeetingsRouteArgs(
        initialTabIndex: MeetingsTab.attendance,
        meetingId: link.paramAsString('meeting_id'),
      ),
    );

    return const DeepLinkHandleResult(handled: true);
  }

  Future<DeepLinkHandleResult> _openPatrols() async {
    final profile = await _getCurrentUserProfile();
    if (profile == null) {
      return const DeepLinkHandleResult(
        handled: false,
        message: 'Please sign in to open this notification.',
      );
    }

    if (profile.roleRank < 60) {
      return const DeepLinkHandleResult(
        handled: false,
        message: 'You are not allowed to open patrol management.',
      );
    }

    await NavigationService.pushNamedAndRemoveUntil(AppRouter.patrolsManagement);
    return const DeepLinkHandleResult(handled: true);
  }

  Future<DeepLinkHandleResult> _openProfile() async {
    if (!await _isAuthenticated()) {
      return const DeepLinkHandleResult(
        handled: false,
        message: 'Please sign in to open this notification.',
      );
    }

    await NavigationService.pushNamedAndRemoveUntil(AppRouter.profile);
    return const DeepLinkHandleResult(handled: true);
  }

  Future<bool> _isAuthenticated() async {
    try {
      final profile = await _getCurrentUserProfile();
      final isAuthenticated = profile != null;
      if (!isAuthenticated && kDebugMode) {
        debugPrint('DeepLinkHandler: ignored request because user is not authenticated.');
      }
      return isAuthenticated;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('DeepLinkHandler._isAuthenticated error: $e\n$st');
      }
      return false;
    }
  }
}
