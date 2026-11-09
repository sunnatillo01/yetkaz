/// Formats an integer amount of so'm with space-separated thousands:
/// `45000` → `45 000`. Amounts are always `int` — never `double`.
String formatMoney(int amount) {
  final negative = amount < 0;
  final digits = amount.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    final remaining = digits.length - i;
    buffer.write(digits[i]);
    if (remaining > 1 && remaining % 3 == 1) buffer.write(' ');
  }
  return negative ? '-$buffer' : buffer.toString();
}
