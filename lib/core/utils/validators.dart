/// Pure validation helpers shared by forms and cubits.
abstract final class Validators {
  /// Uzbek mobile operator codes (first two digits after +998).
  static const _operatorCodes = {
    '20',
    '33',
    '50',
    '55',
    '61',
    '62',
    '65',
    '66',
    '67',
    '69',
    '70',
    '71',
    '72',
    '73',
    '74',
    '75',
    '76',
    '77',
    '78',
    '79',
    '88',
    '90',
    '91',
    '93',
    '94',
    '95',
    '97',
    '98',
    '99',
  };

  /// [digits] — the 9 local digits without `+998`.
  static bool isValidPhone(String digits) {
    final clean = digits.replaceAll(RegExp(r'\D'), '');
    return clean.length == 9 && _operatorCodes.contains(clean.substring(0, 2));
  }

  static bool isValidOtp(String code) => RegExp(r'^\d{6}$').hasMatch(code);

  static bool isValidName(String name) {
    final trimmed = name.trim();
    return trimmed.length >= 2 &&
        trimmed.length <= 40 &&
        RegExp(r"^[\p{L}\s'\-ʻʼ]+$", unicode: true).hasMatch(trimmed);
  }
}
