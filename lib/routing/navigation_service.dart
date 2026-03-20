import 'package:flutter/material.dart';

/// Centralized app navigation service.
///
/// Provides global access to Navigator without requiring BuildContext.
class NavigationService {
  NavigationService._();

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static NavigatorState? get navigator => navigatorKey.currentState;

  static BuildContext? get context => navigatorKey.currentContext;

  static Future<T?> pushNamed<T extends Object?>(
    String routeName, {
    Object? arguments,
  }) {
    final nav = navigator;
    if (nav == null) {
      return Future<T?>.value(null);
    }
    return nav.pushNamed<T>(routeName, arguments: arguments);
  }

  static Future<T?> pushNamedAndRemoveUntil<T extends Object?>(
    String routeName, {
    Object? arguments,
  }) {
    final nav = navigator;
    if (nav == null) {
      return Future<T?>.value(null);
    }
    return nav.pushNamedAndRemoveUntil<T>(
      routeName,
      (route) => false,
      arguments: arguments,
    );
  }

  static void showMessage(String message) {
    final currentContext = context;
    if (currentContext == null) {
      return;
    }

    final messenger = ScaffoldMessenger.maybeOf(currentContext);
    if (messenger == null) {
      return;
    }

    messenger.showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
