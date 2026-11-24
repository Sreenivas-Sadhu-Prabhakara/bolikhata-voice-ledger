import 'package:bolikhata/domain/number_words.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('the documented entries are present', () {
    // These are the entries the app promises in its README, so they are
    // asserted one by one rather than counted.
    const required = <(String, int, UtteranceLanguage)>[
      // Hindi
      ('do sau', 200, UtteranceLanguage.hindi),
      ('ek hazaar', 1000, UtteranceLanguage.hindi),
      ('paanch sau', 500, UtteranceLanguage.hindi),
      ('दो सौ', 200, UtteranceLanguage.hindi),
      ('एक हज़ार', 1000, UtteranceLanguage.hindi),
      ('पाँच सौ', 500, UtteranceLanguage.hindi),
      // Tamil
      ('irunooru', 200, UtteranceLanguage.tamil),
      ('aayiram', 1000, UtteranceLanguage.tamil),
      ('இருநூறு', 200, UtteranceLanguage.tamil),
      ('ஆயிரம்', 1000, UtteranceLanguage.tamil),
      // Tagalog
      ('dalawang daan', 200, UtteranceLanguage.tagalog),
      ('isang libo', 1000, UtteranceLanguage.tagalog),
      // Cebuano
      ('duha ka gatos', 200, UtteranceLanguage.cebuano),
    ];

    for (final (phrase, value, language) in required) {
      test('"$phrase" is $value (${language.label})', () {
        final match = lookupNumberWord(phrase);
        expect(match, isNotNull, reason: '"$phrase" is missing from the table');
        expect(match!.value, value);
        expect(match.language, language);
      });
    }
  });

  group('table hygiene', () {
    test('no phrase is listed twice with two different values', () {
      final seen = <String, int>{};
      final clashes = <String>[];
      for (final table in numberWordTables.entries) {
        for (final word in table.value.entries) {
          final previous = seen[word.key];
          if (previous != null && previous != word.value) {
            clashes.add('${word.key}: $previous vs ${word.value}');
          }
          seen[word.key] = word.value;
        }
      }
      expect(clashes, isEmpty);
    });

    test('every key is lower-cased and trimmed', () {
      for (final table in numberWordTables.values) {
        for (final key in table.keys) {
          expect(key, key.toLowerCase());
          expect(key, key.trim());
          expect(key, isNotEmpty);
          expect(key.contains('  '), isFalse);
        }
      }
    });

    test('every value is a positive whole number', () {
      for (final table in numberWordTables.values) {
        for (final value in table.values) {
          expect(value, greaterThan(0));
        }
      }
    });

    test('all four languages are covered', () {
      expect(numberWordTables.keys, hasLength(UtteranceLanguage.values.length));
      for (final language in UtteranceLanguage.values) {
        expect(numberWordTables[language], isNotNull);
        expect(numberWordTables[language], isNotEmpty);
      }
    });

    test('the merged index holds every phrase from every table', () {
      for (final table in numberWordTables.values) {
        for (final key in table.keys) {
          expect(numberWordIndex.containsKey(key), isTrue, reason: key);
        }
      }
    });

    test('maxNumberWordTokens matches the longest phrase in the tables', () {
      var longest = 1;
      for (final table in numberWordTables.values) {
        for (final key in table.keys) {
          final length = key.split(' ').length;
          if (length > longest) longest = length;
        }
      }
      expect(maxNumberWordTokens, longest);
      expect(maxNumberWordTokens, greaterThanOrEqualTo(3)); // "duha ka gatos"
    });
  });

  group('lookupNumberWord', () {
    test('returns null for anything not in a table', () {
      expect(lookupNumberWord(''), isNull);
      expect(lookupNumberWord('cooking oil'), isNull);
      expect(lookupNumberWord('zxcv'), isNull);
      expect(lookupNumberWord('DO SAU'), isNull); // caller lower-cases first
    });

    test('reports how many tokens a phrase spans', () {
      expect(lookupNumberWord('sau')!.tokenLength, 1);
      expect(lookupNumberWord('do sau')!.tokenLength, 2);
      expect(lookupNumberWord('duha ka gatos')!.tokenLength, 3);
    });
  });
}
