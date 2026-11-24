import 'package:bolikhata/domain/money.dart';
import 'package:bolikhata/domain/number_words.dart';
import 'package:bolikhata/domain/utterance_parser.dart';
import 'package:flutter_test/flutter_test.dart';

/// Minor units for a whole-rupee / whole-peso amount, so the tables below read
/// the way a shopkeeper speaks.
int money(int major) => major * Currency.minorUnitsPerMajor;

/// One row of the parse table.
class Row {
  const Row(
    this.what,
    this.transcript, {
    this.name = '',
    this.amount,
    this.item = '',
    this.source,
    this.language,
  });

  final String what;
  final String transcript;
  final String name;
  final int? amount;
  final String item;
  final AmountSource? source;
  final UtteranceLanguage? language;
}

void expectRow(Row row) {
  final r = parseUtterance(row.transcript);
  expect(r.name, row.name, reason: 'name of "${row.transcript}"');
  expect(r.amount, row.amount, reason: 'amount of "${row.transcript}"');
  expect(r.item, row.item, reason: 'item of "${row.transcript}"');
  if (row.source != null) {
    expect(r.amountSource, row.source, reason: 'source of "${row.transcript}"');
  }
  if (row.language != null) {
    expect(r.language, row.language, reason: 'language of "${row.transcript}"');
  }
  expect(r.transcript, row.transcript);
  expect(r.confidence, inInclusiveRange(0.0, 1.0));
}

void runTable(String groupName, List<Row> rows) {
  group(groupName, () {
    for (final row in rows) {
      test('${row.what}: "${row.transcript}"', () => expectRow(row));
    }
  });
}

void main() {
  runTable('digits, the common shape', const <Row>[
    Row(
      'name, amount, item',
      'Ramu, 200, cooking oil',
      name: 'Ramu',
      amount: 20000,
      item: 'cooking oil',
      source: AmountSource.digits,
    ),
    Row(
      'no punctuation',
      'Ramu 200 cooking oil',
      name: 'Ramu',
      amount: 20000,
      item: 'cooking oil',
    ),
    Row(
      'thousands separator',
      'Ramu 1,200 rice bag',
      name: 'Ramu',
      amount: 120000,
      item: 'rice bag',
    ),
    Row(
      'peso sign',
      'Nena ₱200 mantika',
      name: 'Nena',
      amount: 20000,
      item: 'mantika',
    ),
    Row(
      'rupee sign',
      'Ramu ₹200 tel',
      name: 'Ramu',
      amount: 20000,
      item: 'tel',
    ),
    Row(
      'Rs as its own word',
      'Ramu Rs 200 tel',
      name: 'Ramu',
      amount: 20000,
      item: 'tel',
    ),
    Row(
      'paise are kept',
      'Ramu 200.50 tel',
      name: 'Ramu',
      amount: 20050,
      item: 'tel',
    ),
    Row(
      'shop-slip shorthand',
      'Ramu 200/- tel',
      name: 'Ramu',
      amount: 20000,
      item: 'tel',
    ),
    Row(
      'two-word name',
      'Ramu bhai 200 tel',
      name: 'Ramu bhai',
      amount: 20000,
      item: 'tel',
    ),
    Row(
      'digits beat an English word that looks like a Hindi number',
      'Ramu do 200 tel',
      name: 'Ramu do',
      amount: 20000,
      item: 'tel',
      source: AmountSource.digits,
    ),
  ]);

  runTable('Hindi number words', const <Row>[
    Row(
      'do sau = 200',
      'Ramu do sau tel',
      name: 'Ramu',
      amount: 20000,
      item: 'tel',
      source: AmountSource.numberWords,
      language: UtteranceLanguage.hindi,
    ),
    Row(
      'paanch sau = 500',
      'Ramu paanch sau atta',
      name: 'Ramu',
      amount: 50000,
      item: 'atta',
      language: UtteranceLanguage.hindi,
    ),
    Row(
      'ek hazaar = 1000',
      'Ramu ek hazaar chawal',
      name: 'Ramu',
      amount: 100000,
      item: 'chawal',
      language: UtteranceLanguage.hindi,
    ),
    Row(
      'the ko particle is dropped',
      'Ramu ko paanch sau rupaye',
      name: 'Ramu',
      amount: 50000,
      language: UtteranceLanguage.hindi,
    ),
    Row(
      'a chain adds down from the largest',
      'Ramu ek hazaar do sau pachaas atta',
      name: 'Ramu',
      amount: 125000,
      item: 'atta',
      source: AmountSource.numberWords,
    ),
    Row(
      'do sau pachaas = 250',
      'Ramu do sau pachaas tel',
      name: 'Ramu',
      amount: 25000,
      item: 'tel',
    ),
  ]);

  runTable('Tamil number words', const <Row>[
    Row(
      'irunooru = 200',
      'Murugan irunooru arisi',
      name: 'Murugan',
      amount: 20000,
      item: 'arisi',
      source: AmountSource.numberWords,
      language: UtteranceLanguage.tamil,
    ),
    Row(
      'aayiram = 1000',
      'Murugan aayiram arisi mooti',
      name: 'Murugan',
      amount: 100000,
      item: 'arisi mooti',
      language: UtteranceLanguage.tamil,
    ),
    Row(
      'rupaay is dropped',
      'Murugan irunooru ரூபாய்',
      name: 'Murugan',
      amount: 20000,
      language: UtteranceLanguage.tamil,
    ),
  ]);

  runTable('Tagalog number words', const <Row>[
    Row(
      'dalawang daan = 200',
      'Nena dalawang daan mantika',
      name: 'Nena',
      amount: 20000,
      item: 'mantika',
      source: AmountSource.numberWords,
      language: UtteranceLanguage.tagalog,
    ),
    Row(
      'isang libo = 1000',
      'Nena isang libo bigas',
      name: 'Nena',
      amount: 100000,
      item: 'bigas',
      language: UtteranceLanguage.tagalog,
    ),
    Row(
      'two-word name and the si particle',
      'si Aling Nena dalawang daan mantika',
      name: 'Aling Nena',
      amount: 20000,
      item: 'mantika',
      language: UtteranceLanguage.tagalog,
    ),
    Row(
      'piso is dropped',
      'Nena limang daan piso',
      name: 'Nena',
      amount: 50000,
      language: UtteranceLanguage.tagalog,
    ),
  ]);

  runTable('Cebuano number words', const <Row>[
    Row(
      'duha ka gatos = 200, and the ka inside it survives filler stripping',
      'Dodong duha ka gatos bugas',
      name: 'Dodong',
      amount: 20000,
      item: 'bugas',
      source: AmountSource.numberWords,
      language: UtteranceLanguage.cebuano,
    ),
    Row(
      'usa ka libo = 1000',
      'Dodong usa ka libo asukar',
      name: 'Dodong',
      amount: 100000,
      item: 'asukar',
      language: UtteranceLanguage.cebuano,
    ),
  ]);

  runTable('the amount can be anywhere', const <Row>[
    Row(
      'amount in the middle',
      'Ramu 200 tel',
      name: 'Ramu',
      amount: 20000,
      item: 'tel',
    ),
    Row(
      'amount first, digits',
      '200 Ramu cooking oil',
      name: 'Ramu',
      amount: 20000,
      item: 'cooking oil',
    ),
    Row(
      'amount first, words',
      'dalawang daan Nena mantika',
      name: 'Nena',
      amount: 20000,
      item: 'mantika',
    ),
    Row(
      'amount last, with goods in front of it',
      'Ramu tel 200',
      name: 'Ramu',
      amount: 20000,
      item: 'tel',
    ),
    Row(
      'amount last, words',
      'Ramu tel do sau',
      name: 'Ramu',
      amount: 20000,
      item: 'tel',
    ),
    Row(
      'amount last, multi-word goods',
      'Ramu cooking oil 200',
      name: 'Ramu',
      amount: 20000,
      item: 'cooking oil',
    ),
  ]);

  runTable('a missing item', const <Row>[
    Row('name and digits only', 'Ramu 200', name: 'Ramu', amount: 20000),
    Row('name and words only', 'Ramu do sau', name: 'Ramu', amount: 20000),
    Row(
      'only filler after the amount',
      'Ramu 200 rupaye',
      name: 'Ramu',
      amount: 20000,
    ),
  ]);

  runTable('a missing name', const <Row>[
    Row('amount alone', '200', amount: 20000),
    Row('amount and currency word', '₱200 pesos', amount: 20000),
    Row('words alone', 'do sau', amount: 20000),
    Row('amount and filler', '200 ko', amount: 20000),
  ]);

  runTable('degenerate input', const <Row>[
    Row('empty string', ''),
    Row('spaces only', '   '),
    Row('punctuation only', ',,, ... !!!'),
    Row('newlines and tabs', '\n\t  \n'),
    Row('gibberish', 'asdf qwer zxcv', name: 'asdf', item: 'qwer zxcv'),
    Row('a name and nothing else', 'Ramu', name: 'Ramu'),
    Row('filler only', 'ko na ang', name: ''),
    Row(
      'a digit run too long to be money',
      'Ramu 99999999999999999999 tel',
      name: 'Ramu',
      item: '99999999999999999999 tel',
    ),
    Row(
      'an amount over the cap',
      'Ramu 500000000000 tel',
      name: 'Ramu',
      item: '500000000000 tel',
    ),
  ]);

  runTable('unicode scripts', const <Row>[
    Row(
      'Devanagari, दो सौ = 200',
      'रामू दो सौ तेल',
      name: 'रामू',
      amount: 20000,
      item: 'तेल',
      source: AmountSource.numberWords,
      language: UtteranceLanguage.hindi,
    ),
    Row(
      'Devanagari with the ko particle and a danda',
      'रामू को पाँच सौ रुपये।',
      name: 'रामू',
      amount: 50000,
      language: UtteranceLanguage.hindi,
    ),
    Row(
      'Devanagari, एक हज़ार = 1000',
      'रामू एक हज़ार चावल',
      name: 'रामू',
      amount: 100000,
      item: 'चावल',
      language: UtteranceLanguage.hindi,
    ),
    Row(
      'Devanagari name with digits',
      'रामू 200 तेल',
      name: 'रामू',
      amount: 20000,
      item: 'तेल',
      source: AmountSource.digits,
    ),
    Row(
      'Tamil script, இருநூறு = 200',
      'முருகன் இருநூறு அரிசி',
      name: 'முருகன்',
      amount: 20000,
      item: 'அரிசி',
      source: AmountSource.numberWords,
      language: UtteranceLanguage.tamil,
    ),
    Row(
      'Tamil script, ஆயிரம் = 1000',
      'முருகன் ஆயிரம் அரிசி',
      name: 'முருகன்',
      amount: 100000,
      item: 'அரிசி',
      language: UtteranceLanguage.tamil,
    ),
    Row(
      'emoji survive as an item',
      'Ramu 200 🧴',
      name: 'Ramu',
      amount: 20000,
      item: '🧴',
    ),
  ]);

  group('confidence', () {
    test('an empty transcript scores exactly zero', () {
      expect(parseUtterance('').confidence, 0.0);
      expect(parseUtterance('   ').confidence, 0.0);
      expect(parseUtterance('...').confidence, 0.0);
    });

    test('a complete utterance in digits scores highest', () {
      final r = parseUtterance('Ramu 200 cooking oil');
      expect(r.confidence, closeTo(0.92, 0.0001));
      expect(r.band, ConfidenceBand.high);
    });

    test('number words score a little below digits', () {
      final words = parseUtterance('Ramu do sau tel');
      final digits = parseUtterance('Ramu 200 tel');
      expect(words.confidence, lessThan(digits.confidence));
      expect(words.band, ConfidenceBand.high);
    });

    test('a guessed name costs confidence', () {
      final normal = parseUtterance('Ramu 200 cooking oil');
      final guessed = parseUtterance('200 Ramu cooking oil');
      expect(guessed.nameGuessedAfterAmount, isTrue);
      expect(normal.nameGuessedAfterAmount, isFalse);
      expect(guessed.confidence, lessThan(normal.confidence));
      expect(guessed.band, ConfidenceBand.medium);
    });

    test('no amount is always low confidence', () {
      for (final t in <String>['asdf qwer zxcv', 'Ramu', 'tel atta chawal']) {
        final r = parseUtterance(t);
        expect(r.hasAmount, isFalse, reason: t);
        expect(r.amount, isNull, reason: t);
        expect(r.confidence, lessThan(0.25), reason: t);
        expect(r.band, ConfidenceBand.low, reason: t);
      }
    });

    test('bands split at the documented thresholds', () {
      expect(confidenceBand(0.0), ConfidenceBand.low);
      expect(confidenceBand(confidenceLowCeiling - 0.0001), ConfidenceBand.low);
      expect(confidenceBand(confidenceLowCeiling), ConfidenceBand.medium);
      expect(
        confidenceBand(confidenceHighFloor - 0.0001),
        ConfidenceBand.medium,
      );
      expect(confidenceBand(confidenceHighFloor), ConfidenceBand.high);
      expect(confidenceBand(1.0), ConfidenceBand.high);
    });

    test('parsing is deterministic and always in range', () {
      const transcripts = <String>[
        'Ramu, 200, cooking oil',
        'रामू दो सौ तेल',
        'Dodong duha ka gatos bugas',
        '',
        'asdf',
        '200',
        'Nena ₱1,200.50 mantika at bigas',
      ];
      for (final t in transcripts) {
        final a = parseUtterance(t);
        final b = parseUtterance(t);
        expect(a.confidence, b.confidence, reason: t);
        expect(a.name, b.name, reason: t);
        expect(a.amount, b.amount, reason: t);
        expect(a.item, b.item, reason: t);
        expect(a.confidence, inInclusiveRange(0.0, 1.0), reason: t);
      }
    });
  });

  group('safety', () {
    test('a parsed entry always needs confirmation', () {
      for (final t in <String>['', 'Ramu 200 tel', 'asdf', 'रामू दो सौ तेल']) {
        expect(parseUtterance(t).needsConfirmation, isTrue, reason: t);
      }
    });

    test('an amount is never negative', () {
      for (final t in <String>['Ramu -200 tel', 'Ramu 200 tel', '-200']) {
        final amount = parseUtterance(t).amount;
        if (amount != null) expect(amount, greaterThan(0));
      }
    });

    test('an amount never exceeds the cap', () {
      final r = parseUtterance('Ramu paanch hazaar paanch hazaar tel');
      if (r.amount != null) expect(r.amount, lessThanOrEqualTo(maxAmountMinor));
    });

    test('nothing throws, whatever is heard', () {
      final nasty = <String>[
        '',
        ' ',
        '\u0000',
        ',,,,,,',
        '₹₹₹',
        '200 200 200 200',
        'do sau do sau do sau',
        'a' * 5000,
        '🧴🧴🧴 200 🧴',
        'Ramu\n200\ttel',
        '99999999999999999999999999',
        '0',
        '0.00',
      ];
      for (final t in nasty) {
        expect(() => parseUtterance(t), returnsNormally, reason: t);
      }
    });

    test('a zero amount is read as zero, not dropped', () {
      // The confirmation screen refuses to save it; the parser still reports
      // honestly what it heard.
      final r = parseUtterance('Ramu 0 tel');
      expect(r.amount, 0);
    });

    test('whitespace inside a transcript is collapsed', () {
      final r = parseUtterance('  Ramu   200    cooking   oil  ');
      expect(r.name, 'Ramu');
      expect(r.amount, money(200));
      expect(r.item, 'cooking oil');
    });

    test('toString names the fields without throwing', () {
      expect(parseUtterance('Ramu 200 tel').toString(), contains('Ramu'));
      expect(parseUtterance('').toString(), contains('confidence'));
    });
  });

  group('ParsedEntry.empty', () {
    test('keeps the transcript and reports nothing found', () {
      final r = ParsedEntry.empty('mumble');
      expect(r.transcript, 'mumble');
      expect(r.name, '');
      expect(r.item, '');
      expect(r.amount, isNull);
      expect(r.hasAmount, isFalse);
      expect(r.confidence, 0.0);
      expect(r.amountSource, AmountSource.none);
      expect(r.needsConfirmation, isTrue);
    });
  });
}
