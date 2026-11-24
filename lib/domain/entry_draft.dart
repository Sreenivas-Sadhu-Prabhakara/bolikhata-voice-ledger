/// The draft entry that sits between what was heard and what gets written.
///
/// Everything the confirmation screen shows and edits lives here, so the
/// question "may this be saved?" is answered by a pure function with a test
/// beside it rather than by a disabled button somewhere in the widget tree.
///
/// Pure Dart: nothing in `lib/domain/` imports Flutter.
library;

import 'ledger.dart';
import 'money.dart';
import 'utterance_parser.dart';

/// Why a draft cannot be saved yet.
enum DraftProblem {
  /// No customer to put the entry against.
  nameMissing,

  /// No amount was heard or typed.
  amountMissing,

  /// Zero, which is never a real credit line or payment.
  amountNotPositive,

  /// Over the cap in `money.dart`; almost certainly a mis-hear.
  amountTooLarge,
}

/// A credit-ledger entry that has not been written yet.
class EntryDraft {
  const EntryDraft({
    this.name = '',
    this.amount,
    this.item = '',
    this.kind = EntryKind.creditGiven,
    this.transcript = '',
    this.confidence = 0,
  });

  /// Builds a draft from a parsed utterance. The amount, name and item come
  /// across exactly as heard — nothing is rounded, cleaned up or completed,
  /// because the shopkeeper is about to see all of it.
  factory EntryDraft.fromParsed(
    ParsedEntry parsed, {
    EntryKind kind = EntryKind.creditGiven,
  }) => EntryDraft(
    name: parsed.name,
    amount: parsed.amount,
    item: parsed.item,
    kind: kind,
    transcript: parsed.transcript,
    confidence: parsed.confidence,
  );

  /// Customer name, as spoken or typed.
  final String name;

  /// Minor units, or `null` when nothing has been entered.
  final int? amount;

  /// The goods. Optional: a khata line is often just a name and a number.
  final String item;

  /// Credit given, or payment received.
  final EntryKind kind;

  /// What the speech engine heard, if this draft came from speech.
  final String transcript;

  /// The parser's confidence, carried through so the screen can say how sure
  /// it is. Zero for a typed draft.
  final double confidence;

  /// Whether this draft came from speech rather than the keyboard.
  bool get fromSpeech => transcript.trim().isNotEmpty;

  /// Everything standing between this draft and the book, in the order a
  /// person would fix it.
  List<DraftProblem> problems() {
    final out = <DraftProblem>[];
    if (name.trim().isEmpty) out.add(DraftProblem.nameMissing);
    final a = amount;
    if (a == null) {
      out.add(DraftProblem.amountMissing);
    } else if (a <= 0) {
      out.add(DraftProblem.amountNotPositive);
    } else if (a > maxAmountMinor) {
      out.add(DraftProblem.amountTooLarge);
    }
    return out;
  }

  /// True only when the draft is complete and sane. The save button follows
  /// this, and nothing else may write to the book.
  bool get isSaveable => problems().isEmpty;

  EntryDraft copyWith({
    String? name,
    int? amount,
    bool clearAmount = false,
    String? item,
    EntryKind? kind,
  }) => EntryDraft(
    name: name ?? this.name,
    amount: clearAmount ? null : (amount ?? this.amount),
    item: item ?? this.item,
    kind: kind ?? this.kind,
    transcript: transcript,
    confidence: confidence,
  );
}
