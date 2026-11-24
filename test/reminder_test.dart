import 'package:bolikhata/domain/ledger.dart';
import 'package:bolikhata/domain/money.dart';
import 'package:bolikhata/domain/reminder.dart';
import 'package:flutter_test/flutter_test.dart';

const Customer ramu = Customer(id: 'c1', name: 'Ramu');
const Customer nena = Customer(id: 'c2', name: 'Aling Nena');

/// Words that mean "you owe this". If one of these shows up for a zero or
/// negative balance, the app is dunning someone who owes nothing.
const Map<ReminderLanguage, List<String>> owedWords =
    <ReminderLanguage, List<String>>{
      ReminderLanguage.english: <String>['pending', 'Please pay'],
      ReminderLanguage.hindi: <String>['बाकी है', 'चुका दें'],
      ReminderLanguage.tamil: <String>['பாக்கி உள்ளது', 'செலுத்துங்கள்'],
      ReminderLanguage.tagalog: <String>['Pakibayaran'],
      ReminderLanguage.cebuano: <String>['Palihog bayri'],
    };

void main() {
  group('reminderToneFor', () {
    const cases = <(int, ReminderTone)>[
      (1, ReminderTone.owed),
      (20000, ReminderTone.owed),
      (100000000000, ReminderTone.owed),
      (0, ReminderTone.settled),
      (-1, ReminderTone.advance),
      (-20000, ReminderTone.advance),
    ];

    for (final (balance, tone) in cases) {
      test('$balance is ${tone.name}', () {
        expect(reminderToneFor(balance), tone);
      });
    }
  });

  group('every language writes all three messages', () {
    for (final language in ReminderLanguage.values) {
      test('${language.name}: names the amount when money is owed', () {
        final text = reminderText(
          ramu,
          20000,
          language,
          currency: Currency.inr,
        );
        expect(text, contains('Ramu'));
        expect(text, contains('₹200'));
        expect(text, isNot(contains('-')));
        for (final phrase in owedWords[language]!) {
          expect(text, contains(phrase));
        }
      });

      test('${language.name}: a zero balance asks for nothing', () {
        final text = reminderText(ramu, 0, language, currency: Currency.inr);
        expect(text, contains('Ramu'));
        for (final phrase in owedWords[language]!) {
          expect(
            text,
            isNot(contains(phrase)),
            reason: 'a settled account must not be dunned',
          );
        }
      });

      test('${language.name}: an advance is never rendered as money owed', () {
        final text = reminderText(
          ramu,
          -5000,
          language,
          currency: Currency.inr,
        );
        // The amount is named, without a minus sign...
        expect(text, contains('₹50'));
        expect(text, isNot(contains('-₹')));
        expect(text, isNot(contains('-50')));
        // ...and never as a debt.
        for (final phrase in owedWords[language]!) {
          expect(
            text,
            isNot(contains(phrase)),
            reason: 'an advance must not be asked for',
          );
        }
      });

      test(
        '${language.name}: the message is non-trivial on all three tones',
        () {
          for (final balance in <int>[20000, 0, -5000]) {
            final text = reminderText(
              ramu,
              balance,
              language,
              currency: Currency.inr,
            );
            expect(text.length, greaterThan(30));
            expect(text.trim(), text);
          }
        },
      );
    }
  });

  group('amounts and currency', () {
    test('the peso symbol is used for a Philippine shop', () {
      final text = reminderText(
        nena,
        120050,
        ReminderLanguage.tagalog,
        currency: Currency.php,
      );
      expect(text, contains('₱1,200.50'));
      expect(text, contains('Aling Nena'));
    });

    test('rupees group the Indian way', () {
      final text = reminderText(
        ramu,
        120000,
        ReminderLanguage.english,
        currency: Currency.inr,
      );
      expect(text, contains('₹1,200'));
    });

    test('rupees are the default currency', () {
      expect(
        reminderText(ramu, 20000, ReminderLanguage.english),
        contains('₹200'),
      );
    });

    test('a one-paise balance is still owed', () {
      final text = reminderText(ramu, 1, ReminderLanguage.english);
      expect(text, contains('₹0.01'));
      expect(text, contains('pending'));
    });
  });

  group('shop name', () {
    test('is appended when set', () {
      final text = reminderText(
        ramu,
        20000,
        ReminderLanguage.english,
        shopName: 'Ramu Kirana',
      );
      expect(text, endsWith('— Ramu Kirana'));
    });

    test('is left off when blank or missing', () {
      expect(
        reminderText(ramu, 20000, ReminderLanguage.english, shopName: '   '),
        isNot(contains('—')),
      );
      expect(
        reminderText(ramu, 20000, ReminderLanguage.english),
        isNot(contains('\n')),
      );
    });
  });

  group('names', () {
    test('a name with spaces around it is trimmed', () {
      const padded = Customer(id: 'c3', name: '  Ramu  ');
      final text = reminderText(padded, 20000, ReminderLanguage.english);
      expect(text, contains('Hello Ramu,'));
    });

    test('a unicode name is used as spoken', () {
      const devanagari = Customer(id: 'c4', name: 'रामू');
      expect(
        reminderText(devanagari, 20000, ReminderLanguage.hindi),
        contains('रामू'),
      );
    });

    test('an empty name does not break the message', () {
      const blank = Customer(id: 'c5', name: ' ');
      final text = reminderText(blank, 20000, ReminderLanguage.english);
      expect(text, contains('₹200'));
      expect(text, contains('pending'));
    });
  });

  test('every language has a label for the picker', () {
    for (final language in ReminderLanguage.values) {
      expect(language.label, isNotEmpty);
    }
  });
}
