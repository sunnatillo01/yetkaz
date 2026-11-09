import 'package:flutter/services.dart';

/// Phone helpers for the `+998 90 123 45 67` format.
abstract final class PhoneUtils {
  static const countryCode = '+998';

  /// Local 9 digits → E.164 (`+998901234567`).
  static String toE164(String localDigits) =>
      '$countryCode${localDigits.replaceAll(RegExp(r'\D'), '')}';

  /// Formats local digits as `90 123 45 67` (partial input supported).
  static String formatLocal(String input) {
    final d = input.replaceAll(RegExp(r'\D'), '');
    final clipped = d.length > 9 ? d.substring(0, 9) : d;
    final buffer = StringBuffer();
    for (var i = 0; i < clipped.length; i++) {
      if (i == 2 || i == 5 || i == 7) buffer.write(' ');
      buffer.write(clipped[i]);
    }
    return buffer.toString();
  }

  /// `+998901234567` → `+998 90 123 45 67`.
  static String formatE164(String e164) {
    final digits = e164.replaceAll(RegExp(r'\D'), '');
    final local = digits.startsWith('998') ? digits.substring(3) : digits;
    return '$countryCode ${formatLocal(local)}';
  }
}

/// Input formatter that keeps the field text as `90 123 45 67`.
class UzPhoneInputFormatter extends TextInputFormatter {
  const UzPhoneInputFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final formatted = PhoneUtils.formatLocal(newValue.text);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
