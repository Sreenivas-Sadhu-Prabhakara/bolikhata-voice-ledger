import 'package:bolikhata/domain/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('groupDigits', () {
    const cases = <(String, DigitGrouping, String)>[
      ('0', DigitGrouping.indian, '0'),
      ('7', DigitGrouping.western, '7'),
      ('200', DigitGrouping.indian, '200'),
      ('200', DigitGrouping.western, '200'),
      ('1200', DigitGrouping.indian, '1,200'),
      ('1200', DigitGrouping.western, '1,200'),
      ('99999', DigitGrouping.indian, '99,999'),
      ('100000', DigitGrouping.indian, '1,00,000'),
      ('100000', DigitGrouping.western, '100,000'),
      ('1234567', DigitGrouping.indian, '12,34,567'),
      ('1234567', DigitGrouping.western, '1,234,567'),
      ('123456789', DigitGrouping.indian, '12,34,56,789'),
      ('123456789', DigitGrouping.western, '123,456,789'),
    ];

    for (final (digits, grouping, expected) in cases) {
      test('$digits as ${grouping.name} is $expected', () {
        expect(groupDigits(digits, grouping), expected);
      });
    }
  });

  group('formatMoney', () {
    const cases = <(int, Currency, String)>[
      (0, Currency.inr, '₹0'),
      (0, Currency.php, '₱0'),
      (20000, Currency.inr, '₹200'),
      (20000, Currency.php, '₱200'),
      (20050, Currency.inr, '₹200.50'),
      (20005, Currency.inr, '₹200.05'),
      (120000, Currency.inr, '₹1,200'),
      (100000000, Currency.inr, '₹10,00,000'),
      (100000000, Currency.php, '₱1,000,000'),
      (-5000, Currency.inr, '-₹50'),
      (-5000, Currency.php, '-₱50'),
      (1, Currency.inr, '₹0.01'),
    ];

    for (final (minor, currency, expected) in cases) {
      test('$minor ${currency.code} renders as $expected', () {
        expect(formatMoney(minor, currency), expected);
      });
    }

    test('the symbol can be left off', () {
      expect(formatMoney(120000, Currency.inr, withSymbol: false), '1,200');
    });

    test('formatMoneyAbs drops the sign of a negative balance', () {
      expect(formatMoneyAbs(-5000, Currency.inr), '₹50');
      expect(formatMoneyAbs(5000, Currency.inr), '₹50');
      expect(formatMoneyAbs(0, Currency.php), '₱0');
    });
  });

  group('minorToDecimalString', () {
    const cases = <(int, String)>[
      (0, '0.00'),
      (5, '0.05'),
      (50, '0.50'),
      (20000, '200.00'),
      (20050, '200.50'),
      (-20050, '-200.50'),
      (999999999, '9999999.99'),
    ];

    for (final (minor, expected) in cases) {
      test('$minor exports as $expected', () {
        expect(minorToDecimalString(minor), expected);
      });
    }
  });

  group('minorToInputString', () {
    const cases = <(int, String)>[
      (0, '0'),
      (20000, '200'),
      (20050, '200.50'),
      (20005, '200.05'),
      (120000, '1200'), // no grouping: it goes back into a text field
      (5, '0.05'),
      (-20050, '-200.50'),
    ];

    for (final (minor, expected) in cases) {
      test('$minor shows in a field as $expected', () {
        expect(minorToInputString(minor), expected);
      });
    }

    test('what it writes, parseMoneyDigits reads back', () {
      for (final minor in <int>[0, 1, 99, 100, 20000, 20050, 123456789]) {
        expect(parseMoneyDigits(minorToInputString(minor)), minor);
      }
    });
  });

  group('parseMoneyDigits', () {
    const cases = <(String, int?)>[
      // Plain digits.
      ('200', 20000),
      ('0', 0),
      ('1200', 120000),
      // Separators.
      ('1,200', 120000),
      ('12,34,567', 123456700),
      ('1,234,567', 123456700),
      // Currency markers.
      ('₹200', 20000),
      ('₱200', 20000),
      ('Rs200', 20000),
      ('Rs.200', 20000),
      ('rs.1,200', 120000),
      ('INR200', 20000),
      ('PHP200', 20000),
      ('P200', 20000),
      // Shop-slip shorthand.
      ('200/-', 20000),
      ('200/', 20000),
      // Fractions.
      ('200.50', 20050),
      ('200.5', 20050),
      ('0.75', 75),
      ('₱200.05', 20005),
      // Not numbers.
      ('', null),
      ('   ', null),
      ('tel', null),
      ('Ramu', null),
      ('rupees', null),
      ('piso', null),
      ('rs', null),
      ('₹', null),
      ('200.555', null), // too precise to round silently
      // The cap keeps a mis-heard number from overflowing an int.
      ('1000000000', maxAmountMinor),
      ('1000000001', null),
      ('99999999999999999999', null),
      ('2.0.0', null),
      ('-200', null), // direction never comes from the amount
      ('two hundred', null), // words are the number-word table's job
      ('तेल', null),
      ('200तेल', null),
    ];

    for (final (raw, expected) in cases) {
      test('"$raw" parses to $expected', () {
        expect(parseMoneyDigits(raw), expected);
      });
    }

    test('whitespace around a number is tolerated', () {
      expect(parseMoneyDigits('  200  '), 20000);
    });
  });

  group('Currency', () {
    test('both currencies have 100 minor units', () {
      expect(Currency.minorUnitsPerMajor, 100);
    });

    test('fromCode reads a stored code and falls back to rupees', () {
      expect(Currency.fromCode('INR'), Currency.inr);
      expect(Currency.fromCode('PHP'), Currency.php);
      expect(Currency.fromCode('USD'), Currency.inr);
      expect(Currency.fromCode(null), Currency.inr);
      expect(Currency.fromCode(''), Currency.inr);
    });

    test('every currency has a symbol and a grouping', () {
      for (final c in Currency.values) {
        expect(c.symbol, isNotEmpty);
        expect(c.code.length, 3);
        expect(DigitGrouping.values, contains(c.grouping));
      }
    });
  });
}
