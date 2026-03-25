/// User-friendly error message translator
///
/// Converts technical exceptions and error messages into user-friendly strings
/// that don't expose implementation details or confuse end-users.
class ErrorTranslator {
  /// Translate a technical error message into a user-friendly message
  static String toUserMessage(String? technicalError) {
    if (technicalError == null || technicalError.isEmpty) {
      return 'An unexpected error occurred. Please try again.';
    }

    // Normalize to lowercase for comparison
    final lower = technicalError.toLowerCase();

    if (lower.contains('row-level security policy') ||
        lower.contains('code: 42501')) {
      return 'Create user is blocked by database access policy. Please apply the latest RLS migration and try again.';
    }

    // Map of patterns to user-friendly messages
    const errorPatterns = {
      // Network errors
      'timeout': 'Request timed out. Please check your connection and try again.',
      'network': 'Network error. Please check your internet connection.',
      'connection': 'Connection lost. Please check your internet connection.',

      // Auth errors
      'unauthorized': 'You don\'t have permission to perform this action.',
      'access denied': 'Access denied. Please contact an administrator.',
      'invalid credentials': 'Invalid email or password. Please try again.',
      'already exists': 'This item already exists in the system.',
      'not found': 'The requested item was not found.',

      // Database errors
      'constraint violation': 'This action violates system constraints. Please try again.',
      'database error': 'A database error occurred. Please try again later.',
      'not null constraint': 'Some required information is missing.',

      // Validation errors
      'is required': 'This field is required.',
      'invalid': 'Invalid format.',
      'email': 'Please check your email address.',

      // Role/permission errors
      'rank': 'You don\'t have the required permissions for this action.',
      'role': 'Your role doesn\'t allow this action.',
      'troop': 'Troop assignment issue. Please contact support.',

      // File/storage errors
      'file': 'File operation failed. Please try again.',
      'storage': 'Storage error. Please try again.',
      'not available': 'This feature is not available right now.',
    };

    // Check each pattern
    for (final entry in errorPatterns.entries) {
      if (lower.contains(entry.key)) {
        return entry.value;
      }
    }

    // If it looks like a technical error (starts with specific patterns), hide it
    if (lower.startsWith('type ') ||
        lower.startsWith('class ') ||
        lower.startsWith('exception') ||
        lower.startsWith('error:') ||
        lower.contains('stack trace') ||
        lower.contains('at ') ||
        lower.contains('debug print') ||
        _isLikelyStackTrace(technicalError)) {
      return 'An unexpected error occurred. Please try again or contact support.';
    }

    // For unknown errors, return a generic message
    return 'An unexpected error occurred. Please try again.';
  }

  /// Check if string looks like a stack trace
  static bool _isLikelyStackTrace(String str) {
    final indicators = ['dart:', 'line', '#0', '#1', '#2', 'package:'];
    return indicators.any((indicator) => str.contains(indicator));
  }

  /// Extract just the user-relevant part of an error message
  /// E.g., "Exception: Email already exists" -> "Email already exists"
  static String extractMessage(String technicalError) {
    // Remove common prefixes
    var message = technicalError;

    // Remove exception type prefixes
    final prefixes = [
      'Exception: ',
      'Error: ',
      'ArgumentError: ',
      'TypeError: ',
      'RangeError: ',
      'FormatException: ',
      'StateError: ',
      'UnsupportedError: ',
    ];

    for (final prefix in prefixes) {
      if (message.startsWith(prefix)) {
        message = message.substring(prefix.length);
        break;
      }
    }

    return message.trim();
  }
}
