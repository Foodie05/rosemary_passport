import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rosm_passport_flutter/rosm_passport_flutter.dart';
import 'package:rosemary_ui/rosemary_ui.dart';

void main() {
  testWidgets(
    'registration gives feedback and blocks invalid submission before HTTP',
    (tester) async {
      final requests = <http.Request>[];
      await tester.pumpWidget(
        MaterialApp(
          home: RosmPassportSignInPage(
            client: _client(requests, Completer<http.Response>()),
            config: const RosmPassportSignInConfig(
              enablePhoneCode: false,
              enableEmailCode: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _tapVisible(tester, find.text('立即注册'));
      await _tapVisible(tester, find.text('接受并继续'));
      expect(find.text('不少于 8 个字符'), findsOneWidget);
      final action = find.byWidgetPredicate(
        (w) => w is RosemaryButton && w.label == '注册并继续  →',
      );
      expect(tester.widget<RosemaryButton>(action).onPressed, isNull);
      await tester.enterText(_field('设置密码'), 'aBcDeFgH');
      await tester.pump();
      expect(find.text('字母、数字、符号中至少包含两种。'), findsOneWidget);
      expect(tester.widget<RosemaryButton>(action).onPressed, isNull);
      await tester.enterText(_field('设置密码'), 'orchid-willow');
      await tester.pump();
      expect(find.text('已满足密码要求。'), findsOneWidget);
      expect(tester.widget<RosemaryButton>(action).onPressed, isNotNull);
      expect(requests.where((r) => r.url.path.endsWith('/register')), isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final mode in ['phone', 'email', 'password', 'register', 'recovery']) {
    testWidgets(
      '$mode blocks before captcha/HTTP, dismisses on decline and resumes once on acceptance',
      (tester) async {
        final requests = <http.Request>[];
        var captchas = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: RosmPassportSignInPage(
              client: _client(requests, Completer<http.Response>()),
              config: RosmPassportSignInConfig(
                enablePhoneCode: mode == 'phone',
                enableEmailCode: mode == 'email',
                enablePassword: mode != 'phone' && mode != 'email',
                requestCaptchaToken: () async {
                  captchas++;
                  return 'test-captcha';
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (mode == 'register') {
          await _tapVisible(tester, find.text('立即注册'));
          await _tapVisible(tester, find.text('暂不接受'));
          expect(find.text('创建新账户'), findsNothing);
          expect(captchas, 0);
          await _tapVisible(tester, find.text('立即注册'));
          await _tapVisible(tester, find.text('接受并继续'));
          await _tapVisible(tester, find.byType(RosemaryCheckbox));
          await tester.enterText(_field('邮箱'), 'user@example.com');
        } else if (mode == 'recovery') {
          await _tapVisible(tester, find.text('忘记密码'));
          await _tapVisible(tester, find.text('暂不接受'));
          expect(find.text('邮箱或手机号'), findsNothing);
          expect(captchas, 0);
          await _tapVisible(tester, find.text('忘记密码'));
          await _tapVisible(tester, find.text('接受并继续'));
          await _tapVisible(tester, find.byType(RosemaryCheckbox));
          await tester.enterText(_field('邮箱或手机号'), 'user@example.com');
        } else if (mode == 'phone') {
          await tester.enterText(_field('手机号'), '13800138000');
        } else {
          await tester.enterText(_field('邮箱'), 'user@example.com');
          if (mode == 'password')
            await tester.enterText(_field('密码'), 'legacy input');
        }
        final actionLabel = switch (mode) {
          'password' => '继续登录  →',
          'register' || 'recovery' => '发送',
          'email' => '发送邮箱验证码  →',
          _ => '发送登录验证码  →',
        };
        final before = requests.length;
        await _tapVisible(tester, find.text(actionLabel));
        expect(find.text('是否接受使用条款与隐私政策？'), findsOneWidget);
        expect(captchas, 0);
        expect(requests.length, before);
        await _tapVisible(tester, find.text('暂不接受'));
        expect(find.text('是否接受使用条款与隐私政策？'), findsNothing);
        expect(find.text(actionLabel), findsOneWidget);
        if (find.byType(RosemaryCheckbox).evaluate().isNotEmpty) {
          expect(
            tester
                .widget<RosemaryCheckbox>(find.byType(RosemaryCheckbox))
                .value,
            false,
          );
        }
        expect(requests.length, before);
        await _tapVisible(tester, find.text(actionLabel));
        // System back also dismisses without continuing.
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(requests.length, before);
        await _tapVisible(tester, find.text(actionLabel));
        await _tapVisible(tester, find.text('接受并继续'));
        expect(captchas, 1);
        expect(requests.length, before + 1);
        expect(find.text('是否接受使用条款与隐私政策？'), findsNothing);
        if (mode == 'password') expect(find.text('选择验证方式'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  for (final directStepUp in [false, true]) {
    testWidgets(
      '${directStepUp ? 'phone-code step-up' : 'password MFA'} reveals the email input after sending with the keyboard open',
      (tester) async {
        tester.view.physicalSize = const Size(390, 600);
        tester.view.devicePixelRatio = 1;
        tester.view.viewInsets = const FakeViewPadding(bottom: 280);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        final sent = Completer<http.Response>();
        final requests = <http.Request>[];
        await tester.pumpWidget(
          MaterialApp(
            home: RosmPassportSignInPage(
              client: _client(requests, sent),
              config: RosmPassportSignInConfig(
                enablePhoneCode: directStepUp,
                enableEmailCode: false,
                enablePassword: !directStepUp,
                requestCaptchaToken: () async => 'test-captcha',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await _tapVisible(tester, find.byType(RosemaryCheckbox));
        if (directStepUp) {
          await tester.enterText(_field('手机号'), '13800138000');
          await _tapVisible(tester, find.text('发送登录验证码  →'));
          await tester.enterText(_field('验证码'), '654321');
        } else {
          await tester.enterText(_field('邮箱'), 'user@example.com');
          await tester.enterText(_field('密码'), 'correct horse battery staple');
        }
        await _tapVisible(
          tester,
          find.text(directStepUp ? '登录并授权  →' : '继续登录  →'),
        );
        expect(find.text(directStepUp ? '完成双因素认证' : '选择验证方式'), findsOneWidget);

        await tester.ensureVisible(find.text('邮箱验证码'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('邮箱验证码'));
        await tester.pump();
        final input = _field(directStepUp ? '验证码' : '邮箱验证码');
        expect(input, findsOneWidget);
        expect(
          requests.last.url.path,
          directStepUp
              ? '/api/v1/auth/login-step-up-code'
              : '/api/v1/auth/send-login-code',
        );
        expect(
          jsonDecode(requests.last.body)[directStepUp
              ? 'factor'
              : 'factor_type'],
          'email_code',
        );

        sent.complete(_json({'sent': true, 'retry_after': 45}));
        await tester.pumpAndSettle();
        expect(input.hitTestable(), findsOneWidget);
        expect(tester.widget<EditableText>(input).focusNode.hasFocus, isTrue);
        await tester.enterText(input, '123456');
        expect(tester.widget<EditableText>(input).controller.text, '123456');
        expect(find.text('45秒'), findsOneWidget);
        expect(find.text('完成登录  →'), findsOneWidget);
        await _tapVisible(tester, find.text('完成登录  →'));
        final login = jsonDecode(requests.last.body) as Map<String, dynamic>;
        expect(login[directStepUp ? 'code' : 'email_code'], '123456');
        expect(login['accepted_legal'], isTrue);
        expect(find.text('授权给 Example'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.pumpAndSettle();
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      100,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Finder _field(String label) => find.descendant(
  of: find.byWidgetPredicate(
    (widget) =>
        (widget is RosemaryInput && widget.label == label) ||
        (widget is TextField &&
            (widget.decoration?.labelText == label ||
                widget.decoration?.hintText == label)),
  ),
  matching: find.byType(EditableText),
);

http.Response _json(Map<String, Object?> body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json'},
);

RosmPassportClient _client(
  List<http.Request> requests,
  Completer<http.Response> sent,
) => RosmPassportClient(
  issuer: Uri.parse('https://auth.example.com'),
  clientId: 'com.example.app',
  redirectUri: Uri.parse('com.example.app:/oidc/callback'),
  tokenStore: RosmMemoryTokenStore(),
  lastSignInStore: RosmMemoryLastSignInStore(),
  httpClient: MockClient((request) async {
    requests.add(request);
    switch (request.url.path) {
      case '/api/v1/legal/documents':
        return _json({
          'terms': {'version': 1, 'title': '使用条款', 'content': 'Terms'},
          'privacy': {'version': 1, 'title': '隐私政策', 'content': 'Privacy'},
        });
      case '/api/v1/oidc/native/start':
        return _json({
          'issuer': 'https://auth.example.com',
          'authorization_request': jsonDecode(request.body),
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
        });
      case '/api/v1/auth/password-factors':
        return _json({
          'factors': ['email_code', 'authenticator'],
          'direct_login': false,
        });
      case '/api/v1/auth/send-login-code':
      case '/api/v1/auth/login-step-up-code':
        return sent.future;
      case '/api/v1/auth/send-email-login-code':
      case '/api/v1/auth/send-code':
      case '/api/v1/auth/send-recovery-code':
      case '/api/v1/auth/send-phone-login-code':
        return _json({'sent': true, 'retry_after': 0});
      case '/api/v1/auth/phone-login':
        return http.Response(
          jsonEncode({
            'error': 'mfa_required',
            'message': '完成双因素认证',
            'step_up_challenge': 'test-challenge',
            'factors': ['email_code', 'authenticator'],
          }),
          403,
          headers: {'content-type': 'application/json'},
        );
      case '/api/v1/auth/login':
      case '/api/v1/auth/login-step-up':
        return _json({
          'user': {
            'id': 'user',
            'email': 'user@example.com',
            'nickname': 'User',
            'roles': [],
          },
          'security': {},
        });
      default:
        throw StateError('Unexpected request: ${request.url.path}');
    }
  }),
);
