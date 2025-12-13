import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Smart Attendance - Basic test', () {
    // Basic test to ensure test framework is working
    expect(1 + 1, equals(2));
  });

  test('String manipulation test', () {
    const appName = 'Smart Attendance';
    expect(appName.toLowerCase(), equals('smart attendance'));
    expect(appName.length, greaterThan(0));
  });

  test('List operations test', () {
    final roles = ['student', 'teacher', 'admin'];
    expect(roles.length, equals(3));
    expect(roles.contains('student'), isTrue);
    expect(roles.contains('superadmin'), isFalse);
  });
}
