import 'dart:async';
import 'dart:io';

import '../build/bin/server.dart' as generated;
// Use the bundled service graph as the generated routes. Importing the source
// tree here would create a second AppServices singleton and leak its pool.
import '../build/lib/src/bootstrap.dart';

Future<void> main() async {
  final services = AppServices.instance;
  await services.start();

  final address = InternetAddress.anyIPv6;
  final port = int.tryParse(Platform.environment['PORT'] ?? '8080') ?? 8080;
  final server = await generated.createServer(address, port);
  final stopped = Completer<void>();
  var shuttingDown = false;
  final subscriptions = <StreamSubscription<ProcessSignal>>[];

  Future<void> shutdown(ProcessSignal signal) async {
    if (shuttingDown) {
      return;
    }
    shuttingDown = true;
    // ignore: avoid_print
    print('Received ${signal.name}; draining HTTP requests.');
    try {
      await services.shutdownCoordinator.beginDraining().timeout(
        const Duration(seconds: 10),
      );
    } on TimeoutException {
      // The bounded drain window elapsed; remaining requests are terminated.
    } finally {
      await server.close(force: true).timeout(const Duration(seconds: 2));
      await services.close();
      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
      if (!stopped.isCompleted) {
        stopped.complete();
      }
    }
  }

  subscriptions
    ..add(ProcessSignal.sigterm.watch().listen(shutdown))
    ..add(ProcessSignal.sigint.watch().listen(shutdown));
  await stopped.future;
}
