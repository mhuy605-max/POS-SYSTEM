const int sqliteMaxInteger = 9223372036854775807;

final class DomainValidationException implements Exception {
  const DomainValidationException(this.message);

  final String message;

  @override
  String toString() => 'DomainValidationException: $message';
}

int checkedLineTotal({required int unitPrice, required num quantity}) {
  if (unitPrice < 0) {
    throw const DomainValidationException('Unit price cannot be negative.');
  }
  if (quantity is! int || quantity <= 0) {
    throw const DomainValidationException(
      'Quantity must be a positive integer.',
    );
  }
  if (unitPrice != 0 && quantity > sqliteMaxInteger ~/ unitPrice) {
    throw const DomainValidationException('Line total exceeds SQLite limits.');
  }
  return unitPrice * quantity;
}

int checkedMoneySum(int left, int right) {
  if (left < 0 || right < 0) {
    throw const DomainValidationException('Money cannot be negative.');
  }
  if (left > sqliteMaxInteger - right) {
    throw const DomainValidationException('Money total exceeds SQLite limits.');
  }
  return left + right;
}

String formatVnd(int amount) {
  if (amount < 0) {
    throw const DomainValidationException('Money cannot be negative.');
  }
  final digits = amount.toString();
  final output = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) {
      output.write('.');
    }
    output.write(digits[index]);
  }
  return '${output.toString()}đ';
}
