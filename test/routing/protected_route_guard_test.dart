import 'package:flutter_test/flutter_test.dart';
import 'package:masapp/routing/app_router.dart';

void main() {
  group('evaluateProtectedRouteState', () {
    test('denies unauthenticated access', () {
      final result = evaluateProtectedRouteState(
        isAuthenticated: false,
        profileLoading: false,
        hasProfile: false,
        currentUserRoleRank: 0,
        minRoleRank: 60,
        unresolvedProfileDuration: Duration.zero,
        unresolvedProfileTimeout: const Duration(seconds: 8),
      );

      expect(result.state, ProtectedRouteState.denyUnauthenticated);
    });

    test('stays pending while profile is loading', () {
      final result = evaluateProtectedRouteState(
        isAuthenticated: true,
        profileLoading: true,
        hasProfile: false,
        currentUserRoleRank: 0,
        minRoleRank: 60,
        unresolvedProfileDuration: const Duration(seconds: 2),
        unresolvedProfileTimeout: const Duration(seconds: 8),
      );

      expect(result.state, ProtectedRouteState.pendingProfile);
    });

    test('denies when profile remains unavailable after timeout', () {
      final result = evaluateProtectedRouteState(
        isAuthenticated: true,
        profileLoading: false,
        hasProfile: false,
        currentUserRoleRank: 0,
        minRoleRank: 60,
        unresolvedProfileDuration: const Duration(seconds: 9),
        unresolvedProfileTimeout: const Duration(seconds: 8),
      );

      expect(result.state, ProtectedRouteState.denyProfileUnavailable);
    });

    test('denies insufficient role using current user rank', () {
      final result = evaluateProtectedRouteState(
        isAuthenticated: true,
        profileLoading: false,
        hasProfile: true,
        currentUserRoleRank: 70,
        minRoleRank: 90,
        unresolvedProfileDuration: Duration.zero,
        unresolvedProfileTimeout: const Duration(seconds: 8),
      );

      expect(result.state, ProtectedRouteState.denyInsufficientRole);
    });

    test('allows access when rank requirement is met', () {
      final result = evaluateProtectedRouteState(
        isAuthenticated: true,
        profileLoading: false,
        hasProfile: true,
        currentUserRoleRank: 100,
        minRoleRank: 90,
        unresolvedProfileDuration: Duration.zero,
        unresolvedProfileTimeout: const Duration(seconds: 8),
      );

      expect(result.state, ProtectedRouteState.allow);
      expect(result.isAllowed, isTrue);
    });
  });
}
