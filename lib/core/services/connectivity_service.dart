import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:masapp/core/constants/offline_policy.dart';

class ConnectivityService {
  ConnectivityService._();

  static final ConnectivityService instance = ConnectivityService._();

  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _statusController =
      StreamController<bool>.broadcast();

  StreamSubscription<dynamic>? _subscription;
  Timer? _debounceTimer;
  bool _initialized = false;
  bool _isOnline = true;

  bool get isOnline => _isOnline;
  Stream<bool> get statusStream => _statusController.stream;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    final current = await _connectivity.checkConnectivity();
    _isOnline = _hasConnection(current);
    _statusController.add(_isOnline);

    _subscription = _connectivity.onConnectivityChanged.listen(
      _onRawConnectivityChanged,
      onError: (_) {},
    );
  }

  void _onRawConnectivityChanged(dynamic rawResult) {
    final nextOnline = _hasConnection(rawResult);
    _debounceTimer?.cancel();
    _debounceTimer = Timer(OfflinePolicy.connectivityDebounce, () {
      if (nextOnline == _isOnline) return;
      _isOnline = nextOnline;
      if (!_statusController.isClosed) {
        _statusController.add(_isOnline);
      }
      if (kDebugMode) {
        debugPrint('[NET] status=${_isOnline ? 'online' : 'offline'}');
      }
    });
  }

  bool _hasConnection(dynamic result) {
    if (result is ConnectivityResult) {
      return result != ConnectivityResult.none;
    }

    if (result is List<ConnectivityResult>) {
      return result.any((entry) => entry != ConnectivityResult.none);
    }

    if (result is Iterable<ConnectivityResult>) {
      return result.any((entry) => entry != ConnectivityResult.none);
    }

    return _isOnline;
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _debounceTimer?.cancel();
    await _statusController.close();
  }
}
