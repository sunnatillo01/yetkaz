import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_delivery/core/entities/coordinates.dart';
import 'package:food_delivery/core/utils/debouncer.dart';
import 'package:food_delivery/core/utils/money_formatter.dart';
import 'package:food_delivery/core/utils/phone_formatter.dart';
import 'package:food_delivery/core/utils/validators.dart';

void main() {
  group('formatMoney', () {
    test('groups thousands with a non-breaking space', () {
      expect(formatMoney(0), '0');
      expect(formatMoney(999), '999');
      expect(formatMoney(45000), '45 000');
      expect(formatMoney(1234567), '1 234 567');
      expect(formatMoney(-5000), '-5 000');
    });
  });

  group('Validators', () {
    test('phone requires 9 digits with a valid operator code', () {
      expect(Validators.isValidPhone('901234567'), isTrue);
      expect(Validators.isValidPhone('90 123 45 67'), isTrue);
      expect(Validators.isValidPhone('90123456'), isFalse);
      expect(Validators.isValidPhone('121234567'), isFalse);
      expect(Validators.isValidPhone(''), isFalse);
    });

    test('otp is exactly 6 digits', () {
      expect(Validators.isValidOtp('123456'), isTrue);
      expect(Validators.isValidOtp('12345'), isFalse);
      expect(Validators.isValidOtp('12345a'), isFalse);
    });

    test('name is 2..40 letters (Uzbek apostrophes allowed)', () {
      expect(Validators.isValidName('Ali'), isTrue);
      expect(Validators.isValidName("G'ayrat"), isTrue);
      expect(Validators.isValidName('Олег'), isTrue);
      expect(Validators.isValidName('A'), isFalse);
      expect(Validators.isValidName('   '), isFalse);
      expect(Validators.isValidName('Ali123'), isFalse);
    });
  });

  group('PhoneUtils', () {
    test('formats partial and full input', () {
      expect(PhoneUtils.formatLocal('90'), '90');
      expect(PhoneUtils.formatLocal('90123'), '90 123');
      expect(PhoneUtils.formatLocal('901234567'), '90 123 45 67');
      expect(PhoneUtils.formatLocal('9012345678999'), '90 123 45 67');
    });

    test('converts to and from E.164', () {
      expect(PhoneUtils.toE164('90 123 45 67'), '+998901234567');
      expect(PhoneUtils.formatE164('+998901234567'), '+998 90 123 45 67');
    });

    test('input formatter keeps the mask', () {
      const formatter = UzPhoneInputFormatter();
      final result = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: '9012345'),
      );
      expect(result.text, '90 123 45');
      expect(result.selection.baseOffset, result.text.length);
    });
  });

  group('Debouncer', () {
    test('runs only the last action after the delay', () {
      fakeAsync((async) {
        final debouncer = Debouncer(const Duration(milliseconds: 400));
        final calls = <int>[];
        debouncer
          ..run(() => calls.add(1))
          ..run(() => calls.add(2));
        async.elapse(const Duration(milliseconds: 399));
        expect(calls, isEmpty);
        expect(debouncer.isPending, isTrue);
        async.elapse(const Duration(milliseconds: 1));
        expect(calls, [2]);
      });
    });

    test('cancel prevents the action', () {
      fakeAsync((async) {
        final debouncer = Debouncer(const Duration(milliseconds: 100));
        var called = false;
        debouncer
          ..run(() => called = true)
          ..cancel();
        async.elapse(const Duration(seconds: 1));
        expect(called, isFalse);
      });
    });
  });

  group('Coordinates', () {
    const a = Coordinates(lat: 41.3, lng: 69.2);
    const b = Coordinates(lat: 41.4, lng: 69.3);

    test('distance is symmetric and plausible', () {
      final d = a.distanceTo(b);
      expect(d, closeTo(13.8, 0.5));
      expect(b.distanceTo(a), closeTo(d, 1e-9));
      expect(a.distanceTo(a), 0);
    });

    test('lerp interpolates linearly', () {
      expect(a.lerp(b, 0), a);
      expect(a.lerp(b, 1), b);
      final mid = a.lerp(b, 0.5);
      expect(mid.lat, closeTo(41.35, 1e-9));
      expect(mid.lng, closeTo(69.25, 1e-9));
    });

    test('bearing points north-east', () {
      expect(a.bearingTo(b), inInclusiveRange(30, 60));
    });
  });
}
