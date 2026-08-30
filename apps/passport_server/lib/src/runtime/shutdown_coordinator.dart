import 'dart:async';

/// Coordinates bounded, graceful application shutdown.
class ShutdownCoordinator {
  bool _draining = false;
  int _activeRequests = 0;
  Completer<void>? _drained;

  bool get isDraining => _draining;
  int get activeRequests => _activeRequests;

  /// Returns false once draining has started, so new work can be rejected.
  bool tryEnter() {
    if (_draining) {
      return false;
    }
    _activeRequests += 1;
    return true;
  }

  void leave() {
    if (_activeRequests <= 0) {
      throw StateError('No active request to leave.');
    }
    _activeRequests -= 1;
    if (_activeRequests == 0 && _draining) {
      _drained?.complete();
      _drained = null;
    }
  }

  Future<void> beginDraining() {
    _draining = true;
    if (_activeRequests == 0) {
      return Future<void>.value();
    }
    return (_drained ??= Completer<void>()).future;
  }
}
