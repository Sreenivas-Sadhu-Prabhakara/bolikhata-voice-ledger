import 'package:bolikhata/domain/entry_draft.dart';
import 'package:bolikhata/domain/ledger.dart';
import 'package:bolikhata/domain/money.dart';
import 'package:bolikhata/domain/utterance_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('problems', () {
    const cases = <(String, EntryDraft, List<DraftProblem>)>[
      (
        'a complete draft has none',
        EntryDraft(name: 'Ramu', amount: 20000, item: 'tel'),
        <DraftProblem>[],
      ),
      (
        'an item is optional',
        EntryDraft(name: 'Ramu', amount: 20000),
        <DraftProblem>[],
      ),
      (
        'no name',
        EntryDraft(amount: 20000),
        <DraftProblem>[DraftProblem.nameMissing],
      ),
      (
        'a name of spaces is no name',
        EntryDraft(name: '   ', amount: 20000),
        <DraftProblem>[DraftProblem.nameMissing],
      ),
      (
        'no amount',
        EntryDraft(name: 'Ramu'),
        <DraftProblem>[DraftProblem.amountMissing],
      ),
      (
        'a zero amount',
        EntryDraft(name: 'Ramu', amount: 0),
        <DraftProblem>[DraftProblem.amountNotPositive],
      ),
      (
        'a negative amount',
        EntryDraft(name: 'Ramu', amount: -500),
        <DraftProblem>[DraftProblem.amountNotPositive],
      ),
      (
        'an amount over the cap',
        EntryDraft(name: 'Ramu', amount: maxAmountMinor + 1),
        <DraftProblem>[DraftProblem.amountTooLarge],
      ),
      (
        'exactly the cap is allowed',
        EntryDraft(name: 'Ramu', amount: maxAmountMinor),
        <DraftProblem>[],
      ),
      (
        'nothing at all',
        EntryDraft(),
        <DraftProblem>[DraftProblem.nameMissing, DraftProblem.amountMissing],
      ),
    ];

    for (final (what, draft, expected) in cases) {
      test(what, () {
        expect(draft.problems(), expected);
        expect(draft.isSaveable, expected.isEmpty);
      });
    }
  });

  group('fromParsed', () {
    test('carries name, amount, item, transcript and confidence across', () {
      final parsed = parseUtterance('Ramu, 200, cooking oil');
      final draft = EntryDraft.fromParsed(parsed);
      expect(draft.name, 'Ramu');
      expect(draft.amount, 20000);
      expect(draft.item, 'cooking oil');
      expect(draft.transcript, 'Ramu, 200, cooking oil');
      expect(draft.confidence, parsed.confidence);
      expect(draft.kind, EntryKind.creditGiven);
      expect(draft.fromSpeech, isTrue);
      expect(draft.isSaveable, isTrue);
    });

    test('a parse with no amount is not saveable', () {
      final draft = EntryDraft.fromParsed(parseUtterance('Ramu'));
      expect(draft.problems(), <DraftProblem>[DraftProblem.amountMissing]);
      expect(draft.isSaveable, isFalse);
    });

    test('gibberish produces a draft that must be fixed by hand', () {
      final draft = EntryDraft.fromParsed(parseUtterance('asdf qwer'));
      expect(draft.isSaveable, isFalse);
      expect(draft.confidence, lessThan(0.25));
    });

    test('an empty utterance produces an empty, unsaveable draft', () {
      final draft = EntryDraft.fromParsed(parseUtterance(''));
      expect(draft.name, '');
      expect(draft.amount, isNull);
      expect(draft.fromSpeech, isFalse);
      expect(draft.problems(), <DraftProblem>[
        DraftProblem.nameMissing,
        DraftProblem.amountMissing,
      ]);
    });

    test('a payment can be recorded by voice too', () {
      final draft = EntryDraft.fromParsed(
        parseUtterance('Ramu 200'),
        kind: EntryKind.paymentReceived,
      );
      expect(draft.kind, EntryKind.paymentReceived);
      expect(draft.isSaveable, isTrue);
    });
  });

  group('copyWith', () {
    const base = EntryDraft(
      name: 'Ramu',
      amount: 20000,
      item: 'tel',
      transcript: 'Ramu 200 tel',
      confidence: 0.9,
    );

    test('a correction replaces one field and keeps the rest', () {
      final fixed = base.copyWith(name: 'Ramu Kaka');
      expect(fixed.name, 'Ramu Kaka');
      expect(fixed.amount, 20000);
      expect(fixed.item, 'tel');
      expect(fixed.transcript, 'Ramu 200 tel');
      expect(fixed.confidence, 0.9);
    });

    test('the amount can be cleared, not just changed', () {
      expect(base.copyWith(clearAmount: true).amount, isNull);
      expect(base.copyWith(amount: 500).amount, 500);
      expect(base.copyWith(item: '').item, '');
    });

    test('the kind can be switched to a payment', () {
      expect(
        base.copyWith(kind: EntryKind.paymentReceived).kind,
        EntryKind.paymentReceived,
      );
    });
  });

  group('typed drafts', () {
    test('a keyboard draft is not marked as heard', () {
      const draft = EntryDraft(name: 'Ramu', amount: 20000);
      expect(draft.fromSpeech, isFalse);
      expect(draft.confidence, 0);
      expect(draft.isSaveable, isTrue);
    });

    test('a whitespace transcript does not count as speech', () {
      const draft = EntryDraft(name: 'Ramu', amount: 1, transcript: '   ');
      expect(draft.fromSpeech, isFalse);
    });
  });
}
