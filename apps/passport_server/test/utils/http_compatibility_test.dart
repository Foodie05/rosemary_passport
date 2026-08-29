import 'package:dart_frog/dart_frog.dart';
import 'package:rosm_passport_server/src/utils/http.dart';
import 'package:test/test.dart';

void main() {
  test('OIDC compatibility parser accepts form-urlencoded bodies', () async {
    final request = Request.post(
      Uri.parse('https://passport.example.com/oidc/token'),
      headers: {'content-type': 'application/x-www-form-urlencoded'},
      body: 'grant_type=refresh_token&refresh_token=value%2Bencoded',
    );
    final body = await tryParseJsonOrFormObject(request);
    expect(body?['grant_type'], 'refresh_token');
    expect(body?['refresh_token'], 'value+encoded');
  });
}
