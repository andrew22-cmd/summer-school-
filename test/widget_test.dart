import 'package:flutter_test/flutter_test.dart';
import 'package:summerschool/utils/validators.dart';

void main() {
  group('Validators', () {
    test('email validator should accept valid email', () {
      expect(Validators.email('user@example.com'), isNull);
    });

    test('email validator should reject invalid email', () {
      expect(Validators.email('invalid-email'), isNotNull);
    });

    test('password validator should reject short password', () {
      expect(Validators.password('123'), isNotNull);
    });
  });
}
