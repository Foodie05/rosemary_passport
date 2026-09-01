import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rosm_passport_flutter/rosm_passport_flutter.dart';

void main() {
  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher
        .clearPlatformBrightnessTestValue();
  });

  testWidgets('system mode follows the platform dark appearance', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await _pumpSignIn(tester, RosmPassportThemeMode.system);

    final theme = Theme.of(tester.element(find.byType(Scaffold)));
    expect(theme.brightness, Brightness.dark);
  });

  testWidgets('explicit light mode overrides a dark host application', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: RosmPassportSignInPage(
          client: _client(),
          config: const RosmPassportSignInConfig(
            themeMode: RosmPassportThemeMode.light,
          ),
        ),
      ),
    );
    await tester.pump();

    final theme = Theme.of(tester.element(find.byType(Scaffold)));
    expect(theme.brightness, Brightness.light);
  });

  testWidgets('phone input uses a readable on-surface text color', (
    tester,
  ) async {
    await _pumpSignIn(tester, RosmPassportThemeMode.dark);
    await tester.enterText(find.byType(TextField).first, '13800138000');

    final editable = tester.widget<EditableText>(
      find.byType(EditableText).first,
    );
    final theme = Theme.of(tester.element(find.byType(EditableText).first));
    expect(editable.style.color, theme.colorScheme.onSurface);
    expect(editable.style.color, isNot(theme.colorScheme.surface));
  });
}

Future<void> _pumpSignIn(
  WidgetTester tester,
  RosmPassportThemeMode themeMode,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: RosmPassportSignInPage(
        client: _client(),
        config: RosmPassportSignInConfig(themeMode: themeMode),
      ),
    ),
  );
  await tester.pump();
}

RosmPassportClient _client() {
  return RosmPassportClient(
    issuer: Uri.parse('https://auth.example.com'),
    clientId: 'com.example.app',
    redirectUri: Uri.parse('com.example.app:/oidc/callback'),
    tokenStore: RosmMemoryTokenStore(),
    lastSignInStore: RosmMemoryLastSignInStore(),
    httpClient: MockClient((request) async {
      final requestBody = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode({
          'issuer': 'https://auth.example.com',
          'authorization_request': requestBody,
          'client': {
            'client_id': 'com.example.app',
            'display_name': 'Example',
            'is_official': false,
            'is_confidential': false,
          },
          'scopes': [
            {'name': 'openid', 'description': 'Sign in'},
          ],
          'pkce_required': true,
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }),
  );
}
