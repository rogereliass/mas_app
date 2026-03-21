import 'deep_link_handler.dart';
import 'deep_link_model.dart';
import 'deep_link_parser.dart';

/// Single public entry point for all deep-link style actions.
///
/// Supported sources include:
/// - In-app notification taps
/// - Future Firebase Messaging tap events
/// - Future QR scan payload events
/// - Future external URL routing events
class DeepLinkService {
  DeepLinkService._();

  static final DeepLinkHandler _handler = DeepLinkHandler();

  static Future<DeepLinkHandleResult> handle(Map<String, dynamic> data) async {
    final model = DeepLinkParser.parse(data);
    return _handler.handle(model);
  }
}
