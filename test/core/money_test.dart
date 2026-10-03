import 'package:dakao_in_bill/core/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('integer VND arithmetic', () {
    test('formats whole VND without floating point', () {
      expect(formatVnd(45000), '45.000đ');
      expect(formatVnd(0), '0đ');
    });

    test('calculates a line total with checked multiplication', () {
      expect(checkedLineTotal(unitPrice: 45000, quantity: 2), 90000);
    });

    test('rejects zero, negative, and fractional quantities', () {
      for (final quantity in <num>[0, -1, 1.5]) {
        expect(
          () => checkedLineTotal(unitPrice: 45000, quantity: quantity),
          throwsA(isA<DomainValidationException>()),
          reason: 'quantity $quantity must be rejected',
        );
      }
    });

    test('rejects negative money', () {
      expect(
        () => checkedLineTotal(unitPrice: -1, quantity: 1),
        throwsA(isA<DomainValidationException>()),
      );
    });

    test('rejects signed 64-bit multiplication overflow', () {
      expect(
        () => checkedLineTotal(unitPrice: sqliteMaxInteger, quantity: 2),
        throwsA(isA<DomainValidationException>()),
      );
    });

    test('rejects signed 64-bit addition overflow', () {
      expect(
        () => checkedMoneySum(sqliteMaxInteger, 1),
        throwsA(isA<DomainValidationException>()),
      );
    });
  });
}
