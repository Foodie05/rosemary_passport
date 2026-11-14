import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rosemary_ui/rosemary_ui.dart';
import 'package:rosm_passport_flutter/rosm_passport_flutter.dart';
import 'package:rosm_passport_flutter/src/account_step_up.dart';
import 'package:rosm_passport_flutter/src/forma_controls.dart';
import 'package:rosm_passport_flutter/src/rosm_passport_theme.dart';

void main() {
  test(
    'account APIs submit actor proofs without changing legacy calls',
    () async {
      final requests = <http.Request>[];
      final client = _client(requests);
      const proof = RosmStepUpProof.authenticator('123456');
      await client.bindEmail(
        email: 'new@example.invalid',
        emailCode: '654321',
        verification: proof,
      );
      expect(jsonDecode(requests.last.body)['verification'], {
        'method': 'authenticator',
        'code': '123456',
      });
      await client.bindPhone(
        phoneNumber: '13800138000',
        verifyCode: '654321',
        verification: const RosmStepUpProof.emailCode('123456'),
      );
      expect(
        jsonDecode(requests.last.body)['verification']['method'],
        'email_code',
      );
      await client.resetOwnPassword(
        newPassword: 'orchid-willow',
        verification: proof,
      );
      expect(
        jsonDecode(requests.last.body)['verification']['method'],
        'authenticator',
      );
      await client.verifyAuthenticatorSetup(
        secret: 'fixture',
        code: '654321',
        verification: const RosmStepUpProof.phoneCode('123456'),
      );
      expect(
        jsonDecode(requests.last.body)['verification']['method'],
        'phone_code',
      );
      await client.bindEmail(
        email: 'legacy@example.invalid',
        emailCode: '654321',
        currentPassword: 'legacy',
      );
      final legacy = jsonDecode(requests.last.body) as Map;
      expect(legacy.containsKey('verification'), isFalse);
      expect(legacy['current_password'], 'legacy');
      await client.sendAccountStepUpCode(
        method: 'phone_code',
        excludedFactor: 'email',
      );
      expect(requests.last.url.path, '/api/v1/me/step-up/send-code');
      expect(jsonDecode(requests.last.body), {
        'method': 'phone_code',
        'excluded_factor': 'email',
      });
      await client.accountStepUpPasskeyOptions(excludedFactor: 'password');
      expect(requests.last.url.path, '/api/v1/me/step-up/webauthn-options');
      expect(jsonDecode(requests.last.body), {'excluded_factor': 'password'});
    },
  );
  test(
    'security metadata includes current eligible factors and legacy defaults',
    () {
      final current = RosmSecurityState.fromJson({
        'has_password': false,
        'has_passkey': true,
        'step_up_methods': ['phone_code', 'passkey'],
      });
      expect(current.hasPassword, isFalse);
      expect(current.hasPasskey, isTrue);
      expect(current.stepUpMethods, ['phone_code', 'passkey']);
      expect(RosmSecurityState.fromJson({}).hasPassword, isTrue);
      expect(const RosmStepUpProof.password('legacy').toJson(), {
        'method': 'password',
        'password': 'legacy',
      });
      expect(
        const RosmStepUpProof.passkey({
          'id': 'fixture',
          'response': {'signature': 'fixture'},
        }).toJson()['method'],
        'passkey',
      );
    },
  );
  testWidgets(
    'account password change uses a selected bound factor and displays rejection',
    (tester) async {
      tester.view.physicalSize = const Size(600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final requests = <http.Request>[];
      final client = RosmPassportClient(
        issuer: Uri.parse('https://auth.example.invalid'),
        clientId: 'fixture',
        redirectUri: Uri.parse('com.example.fixture:/callback'),
        tokenStore: RosmMemoryTokenStore(),
        lastSignInStore: RosmMemoryLastSignInStore(),
        httpClient: MockClient((request) async {
          requests.add(request);
          if (request.url.path == '/api/v1/me') {
            return http.Response(
              jsonEncode({
                'user': {
                  'id': 'fixture',
                  'email': 'fixture@example.invalid',
                  'nickname': 'Fixture',
                  'roles': ['user'],
                },
                'security': {
                  'has_password': true,
                  'has_authenticator': true,
                  'step_up_methods': ['password', 'authenticator'],
                },
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response(
            jsonEncode({
              'error': 'verification_failed',
              'message': '验证码无效，请重新输入',
            }),
            400,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: RosmPassportAccountPage(
            client: client,
            config: RosmPassportAccountConfig(reauthenticate: () async => true),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(RosemaryCard), findsNWidgets(3));
      expect(find.text('安全提示'), findsNothing);
      await tester.ensureVisible(find.text('重置'));
      await tester.tap(find.text('重置'));
      await tester.pumpAndSettle();
      final select = tester.widget<RosemarySelect>(find.byType(RosemarySelect));
      expect(select.options.map((option) => option.id), ['authenticator']);
      Finder field(String label) => find.descendant(
        of: find.byWidgetPredicate(
          (w) => w is RosmEpassInput && w.decoration.labelText == label,
        ),
        matching: find.byType(EditableText),
      );
      await tester.enterText(field('新密码'), 'orchid-willow');
      await tester.enterText(field('Authenticator 动态码'), '123456');
      final submit = find.byWidgetPredicate(
        (w) => w is RosemaryButton && w.label == '重置密码',
      );
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      final request = requests.last;
      expect(request.url.path, '/api/v1/me/reset-password');
      expect(jsonDecode(request.body)['verification'], {
        'method': 'authenticator',
        'code': '123456',
      });
      expect(
        find.descendant(
          of: find.byType(RosmAccountStepUp),
          matching: find.text('验证码无效，请重新输入'),
        ),
        findsOneWidget,
      );
      expect(
        tester.widget<EditableText>(field('Authenticator 动态码')).controller.text,
        isEmpty,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'native proof editor excludes the changed factor and clears proof on selection',
    (tester) async {
      RosmStepUpProof? proof;
      late StateSetter update;
      String? failure;
      final client = _client([]);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => RosmEpassTheme(
              data: buildRosmPassportTheme(
                context,
                RosmPassportThemeMode.light,
              ),
              child: Scaffold(
                body: StatefulBuilder(
                  builder: (context, setState) {
                    update = setState;
                    return RosmAccountStepUp(
                      resetToken: failure,
                      client: client,
                      methods: const [
                        'password',
                        'email_code',
                        'authenticator',
                      ],
                      excludedFactor: 'password',
                      onChanged: (value) => proof = value,
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
      final select = tester.widget<RosemarySelect>(find.byType(RosemarySelect));
      expect(select.options.map((option) => option.id), [
        'email_code',
        'authenticator',
      ]);
      await tester.enterText(find.byType(EditableText), '123456');
      expect(proof!.method, 'email_code');
      select.onChanged('authenticator');
      await tester.pumpAndSettle();
      expect(proof, isNull);
      expect(
        tester
            .widget<RosmEpassInput>(find.byType(RosmEpassInput))
            .controller
            .text,
        isEmpty,
      );
      await tester.enterText(find.byType(EditableText), '654321');
      expect(proof!.method, 'authenticator');
      update(() => failure = '验证未通过，请重新输入');
      await tester.pumpAndSettle();
      expect(proof, isNull);
      expect(find.text('验证未通过，请重新输入'), findsOneWidget);
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).controller.text,
        isEmpty,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

RosmPassportClient _client(List<http.Request> requests) => RosmPassportClient(
  issuer: Uri.parse('https://auth.example.invalid'),
  clientId: 'fixture',
  redirectUri: Uri.parse('com.example.fixture:/callback'),
  tokenStore: RosmMemoryTokenStore(),
  lastSignInStore: RosmMemoryLastSignInStore(),
  httpClient: MockClient((request) async {
    requests.add(request);
    return http.Response(
      jsonEncode({'updated': true, 'sent': true, 'retry_after': 0}),
      200,
      headers: {'content-type': 'application/json'},
    );
  }),
);
