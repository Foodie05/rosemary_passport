import 'dart:async';

import 'package:rosm_passport_server/src/runtime/shutdown_coordinator.dart';
import 'package:test/test.dart';

void main() {
  group('ShutdownCoordinator', () {
    test('rejects new work and completes after active work leaves', () async {
      final coordinator = ShutdownCoordinator();
      expect(coordinator.tryEnter(), isTrue);
      expect(coordinator.activeRequests, 1);

      var drained = false;
      final drain = coordinator.beginDraining().then((_) => drained = true);
      expect(coordinator.isDraining, isTrue);
      expect(coordinator.tryEnter(), isFalse);
      await Future<void>.delayed(Duration.zero);
      expect(drained, isFalse);

      coordinator.leave();
      await drain;
      expect(drained, isTrue);
      expect(coordinator.activeRequests, 0);
    });

    test('completes immediately when there is no active work', () async {
      final coordinator = ShutdownCoordinator();
      await coordinator.beginDraining();
      expect(coordinator.isDraining, isTrue);
      expect(coordinator.tryEnter(), isFalse);
    });

    test('guards against unbalanced leave calls', () {
      final coordinator = ShutdownCoordinator();
      expect(coordinator.leave, throwsStateError);
    });
  });
}
