import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:mailer/mailer.dart';
// Exercise the wire representation of our pinned mailer dependency without SMTP.
import 'package:mailer/src/mime/mime.dart';
import 'package:mailer/src/smtp/capabilities.dart';
import 'package:test/test.dart';

import '../../lib/src/utils/epass_email.dart';
import '../../lib/src/utils/verification_email.dart';

Message verification(Map<String, dynamic> template) => buildVerificationEmail(
  from: Address('sender@example.test', 'Rosemary Epass'),
  recipient: 'recipient@example.test',
  code: '123456',
  template: template,
);

void main() {
  final template = {
    'subject': 'Rosemary Epass 验证码',
    'html': epassVerificationEmail,
    'text': '验证码 {{code}}',
  };

  test(
    'brand image is a matching inline PNG, independent of website access',
    () async {
      final message = verification(template);
      expect(message.html, contains('src="cid:$epassEmailLogoCid"'));
      expect(message.html, isNot(contains('{{')));
      expect(message.html, contains('123456'));
      expect(message.text, '验证码 123456');
      final logo = message.attachments.single;
      expect(logo.location, Location.inline);
      expect(logo.cid, '<$epassEmailLogoCid>');
      expect(logo.contentType, 'image/png');
      final bytes = await logo.asStream().fold<List<int>>(
        [],
        (a, b) => a..addAll(b),
      );
      expect(bytes.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
      final png = ByteData.sublistView(Uint8List.fromList(bytes));
      expect([png.getUint32(16), png.getUint32(20)], [128, 128]);
      expect(bytes.length, lessThan(24 * 1024));
      final manifest = jsonDecode(
        File('../../web/src/design/manifest.json').readAsStringSync(),
      );
      expect(
        sha256.convert(bytes).toString(),
        manifest['brand']['emailLogo']['sha256'],
      );
    },
  );

  test(
    'serialized MIME contains the image and its matching content ID',
    () async {
      final message = verification(template);
      final bytes = await MimeMessage(
        message,
      ).data(const Capabilities()).fold<List<int>>([], (a, b) => a..addAll(b));
      final wire = utf8.decode(bytes);
      expect(wire, contains('multipart/related'));
      expect(wire, contains('image/png'));
      expect(
        wire,
        matches(
          RegExp('content-id: <$epassEmailLogoCid>', caseSensitive: false),
        ),
      );
      expect(wire, contains('inline;'));
      final image = File(
        '../../web/public/brand/rosemary-email.png',
      ).readAsBytesSync();
      expect(wire.replaceAll('\r\n', ''), contains(base64Encode(image)));
    },
  );

  test('all historic default templates get the embedded brand', () {
    for (final html in legacyEpassEmailHtml) {
      final message = verification({
        'html': html,
        'subject': 'ROSM通行证',
        'text': '{{code}}',
      });
      expect(message.html, contains('cid:$epassEmailLogoCid'));
      expect(message.attachments, hasLength(1));
      expect(message.subject, 'Rosemary Epass');
    }
  });

  test('custom templates without a brand placeholder stay attachment-free', () {
    final message = verification({
      'html': '<p>自定义 {{code}}</p>',
      'subject': '专用标题',
      'text': '{{code}}',
    });
    expect(message.html, '<p>自定义 123456</p>');
    expect(message.subject, '专用标题');
    expect(message.attachments, isEmpty);
  });
}
