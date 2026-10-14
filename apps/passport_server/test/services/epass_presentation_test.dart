import 'package:test/test.dart';
import '../../lib/src/utils/epass_design.dart';
import '../../lib/src/utils/epass_email.dart';

void main() {
  test(
    'known seed email templates adopt the shared brand without rewriting custom templates',
    () {
      for (final html in legacyEpassEmailHtml) {
        final normalized = normalizeEpassEmailTemplate({
          'html': html,
          'subject': 'ROSM通行证验证码',
          'text': 'ROSM通行证 {{code}}',
        });
        expect(normalized['html'], contains('{{code}}'));
        expect(normalized['html'], contains('{{brand_logo_url}}'));
        expect(normalized['html'], contains('Rosemary'));
        expect(normalized['html'], contains('#315747'));
        expect(normalized['subject'], 'Rosemary Epass验证码');
      }
      final custom = {'html': '<p>自定义 {{code}}</p>', 'subject': '专用标题'};
      expect(identical(normalizeEpassEmailTemplate(custom), custom), isTrue);
    },
  );
  test(
    'standalone full and compact brand preserve names, rounded geometry and tonal roles',
    () {
      expect(
        epassBrandMarkup('/brand/rosemary.png'),
        contains('Rosemary Epass'),
      );
      final compact = epassBrandMarkup('/brand/rosemary.png', compact: true);
      expect(compact, contains('>Epass<'));
      expect(compact, contains('rx="14"'));
      expect(compact, contains('opacity="0.18"'));
      expect(compact, contains('var(--r-semantic-color-on-primary)'));
    },
  );
}
