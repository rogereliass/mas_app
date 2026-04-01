import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ExternalLauncher {
  ExternalLauncher._();

  static Future<bool> openExternalUrl(
    BuildContext context,
    String url, {
    String failureMessage = 'Unable to open link on this device.',
  }) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      _showFailure(context, failureMessage);
      return false;
    }

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!context.mounted) {
        return launched;
      }

      if (!launched) {
        _showFailure(context, failureMessage);
      }

      return launched;
    } catch (_) {
      if (!context.mounted) {
        return false;
      }

      _showFailure(context, failureMessage);
      return false;
    }
  }

  static Future<bool> composeEmail(
    BuildContext context, {
    required String email,
    String? subject,
    String? body,
    String failureMessage = 'Unable to open your email app on this device.',
  }) async {
    final queryParameters = <String, String>{
      if (subject != null && subject.isNotEmpty) 'subject': subject,
      if (body != null && body.isNotEmpty) 'body': body,
    };

    final uri = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters:
          queryParameters.isEmpty ? null : queryParameters,
    );

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!context.mounted) {
        return launched;
      }

      if (!launched) {
        _showFailure(context, failureMessage);
      }

      return launched;
    } catch (_) {
      if (!context.mounted) {
        return false;
      }

      _showFailure(context, failureMessage);
      return false;
    }
  }

  static void _showFailure(BuildContext context, String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      return;
    }

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }
}
