import 'package:flutter/foundation.dart';

enum DeepLinkType {
  meeting,
  attendance,
  patrol,
  profile,
  unknown,
}

@immutable
class DeepLinkModel {
  const DeepLinkModel({
    required this.type,
    required this.params,
    required this.isValid,
    this.error,
  });

  final DeepLinkType type;
  final Map<String, dynamic> params;
  final bool isValid;
  final String? error;

  String? paramAsString(String key) {
    final value = params[key];
    if (value is String) {
      final normalized = value.trim();
      return normalized.isEmpty ? null : normalized;
    }
    if (value == null) {
      return null;
    }
    final normalized = value.toString().trim();
    return normalized.isEmpty ? null : normalized;
  }
}

@immutable
class DeepLinkHandleResult {
  const DeepLinkHandleResult({
    required this.handled,
    this.message,
  });

  final bool handled;
  final String? message;
}
