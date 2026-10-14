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

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final dark in [false, true]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
          '320px sign-in fits $platform dark=$dark textScale=$scale',
          (tester) async {
            tester.view.physicalSize = const Size(320, 900);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            await tester.pumpWidget(
              MaterialApp(
                theme: ThemeData(platform: platform),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: RosmPassportSignInPage(
                  client: _client(),
                  config: RosmPassportSignInConfig(
                    themeMode: dark
                        ? RosmPassportThemeMode.dark
                        : RosmPassportThemeMode.light,
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            expect(find.text('Rosemary'), findsOneWidget);
            expect(find.byType(EditableText), findsWidgets);
            await tester.scrollUntilVisible(
              find.text('我已阅读并同意'),
              240,
              scrollable: find.byType(Scrollable).first,
            );
            await tester.pumpAndSettle();
            expect(find.text('我已阅读并同意'), findsOneWidget);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

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
    await tester.enterText(find.byType(EditableText).first, '13800138000');

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
      if (request.url.path.endsWith('/public/config'))
        return http.Response(
          '{}',
          200,
          headers: {'content-type': 'application/json'},
        );
      if (request.url.path.endsWith('/legal/documents'))
        return http.Response(
          jsonEncode({
            'terms': {'version': 1, 'title': '测试使用条款', 'content': '无效力的测试文档'},
            'privacy': {'version': 1, 'title': '测试隐私政策', 'content': '无效力的测试文档'},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      final requestBody = request.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(request.body) as Map<String, dynamic>;
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
