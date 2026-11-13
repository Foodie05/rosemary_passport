import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:test/test.dart';

void main() {
  test('transport omits framework header on success and failure', () async {
    final server = await serve(
      (context) =>
          Response(statusCode: context.request.uri.path == '/ok' ? 200 : 404),
      InternetAddress.loopbackIPv4,
      0,
      poweredByHeader: null,
    );
    final client = HttpClient();
    try {
      for (final path in ['/ok', '/missing']) {
        final request = await client.getUrl(
          Uri.parse('http://127.0.0.1:${server.port}$path'),
        );
        final response = await request.close();
        expect(response.headers.value('x-powered-by'), isNull);
        expect(response.statusCode, path == '/ok' ? 200 : 404);
        await response.drain<void>();
      }
    } finally {
      client.close(force: true);
      await server.close(force: true);
    }
  });
}
