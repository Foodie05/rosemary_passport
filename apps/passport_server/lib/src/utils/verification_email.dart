import 'dart:convert';

import 'package:mailer/mailer.dart';

import 'epass_email.dart';
import 'epass_email_logo.dart';

const epassEmailLogoCid = 'rosemary-brand@epass';

// Bundle the image in the MIME message so rendering does not require a request
// to the website, its CDN or a signed object-storage URL.
Message buildVerificationEmail({
  required Address from,
  required String recipient,
  required String code,
  required Map<String, dynamic> template,
}) {
  final normalized = normalizeEpassEmailTemplate(template);
  String render(String field) => (normalized[field]?.toString() ?? '')
      .replaceAll('{{code}}', code)
      .replaceAll('{{brand_logo_url}}', 'cid:$epassEmailLogoCid');
  final message = Message()
    ..from = from
    ..recipients.add(recipient)
    ..subject = render('subject')
    ..text = render('text')
    ..html = render('html');
  if (message.html!.contains('cid:$epassEmailLogoCid')) {
    final logo =
        StreamAttachment(
            Stream.value(base64Decode(epassEmailLogoBase64)),
            'image/png',
            fileName: 'rosemary.png',
          )
          ..cid = '<$epassEmailLogoCid>'
          ..location = Location.inline;
    logo.additionalHeaders['X-Attachment-Id'] = epassEmailLogoCid;
    message.attachments.add(logo);
  }
  return message;
}
