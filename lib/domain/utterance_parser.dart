/// Turns one spoken sentence into a draft credit-ledger entry.
///
/// This is the heart of the app: a shopkeeper with flour on their hands says
/// "Ramu, 200, cooking oil" in whatever language they think in, and this file
/// has to find the customer, the amount and the goods in it.
///
/// It is deliberately a small, readable set of rules rather than a model:
/// every decision below can be read, argued with and corrected on screen.
///
/// **The result is always a draft.** [ParsedEntry.needsConfirmation] is always
/// true and nothing in this file saves anything. The caller must show the
/// parsed name, amount and item to the shopkeeper, let them edit every field,
/// and save only on an explicit tap. A mis-heard amount in a credit ledger is
/// money lost, so the app never auto-saves what it thinks it heard.
///
/// Pure Dart: nothing in `lib/domain/` imports Flutter.
library;

import 'money.dart';
import 'number_words.dart';

/// Where the amount in a [ParsedEntry] came from.
enum AmountSource {
  /// No amount was found in the transcript.
  none,

  /// Read from digits, e.g. `200`, `1,200`, `₱200`.
  digits,

  /// Read from number words, e.g. `do sau`, `dalawang daan`.
  numberWords,
}

/// How much of the transcript the parser believes it understood.
enum ConfidenceBand {
  /// Treat the draft as a starting point; expect the shopkeeper to retype.
  low,

  /// Plausible, but worth a careful look.
  medium,

  /// Everything was found where it was expected.
  high,
}

/// Confidence weights. The arithmetic is spelled out here so the numbers on
/// screen can be explained rather than guessed at.
///
/// confidence = [confidenceAmountFound] (or [confidenceNoAmount])
///   + [confidenceDigitsBonus] when the amount came from digits
///   + [confidenceWordsBonus] when it came from number words
///   + [confidenceNameFound] when a name stood before the amount
///   + [confidenceNameGuessed] when the name had to be guessed from after it
///   + [confidenceItemFound] when goods were named
/// clamped to 0.0 .. 1.0. An empty transcript scores exactly 0.0.
const double confidenceAmountFound = 0.45;
const double confidenceNoAmount = 0.08;
const double confidenceDigitsBonus = 0.12;
const double confidenceWordsBonus = 0.05;
const double confidenceNameFound = 0.25;
const double confidenceNameGuessed = 0.05;
const double confidenceItemFound = 0.10;

/// Below this, show the draft as unreliable.
const double confidenceLowCeiling = 0.45;

/// At or above this, the draft can be presented as read.
const double confidenceHighFloor = 0.75;

/// Returns the band [confidence] falls in.
ConfidenceBand confidenceBand(double confidence) {
  if (confidence < confidenceLowCeiling) return ConfidenceBand.low;
  if (confidence < confidenceHighFloor) return ConfidenceBand.medium;
  return ConfidenceBand.high;
}

/// Filler tokens dropped from the name and the item once the amount has been
/// located.
///
/// Two kinds: grammatical particles that glue a shop sentence together
/// (Hindi `ko`, Tagalog `ang`/`ng`/`si`, Cebuano `ka`) and spoken currency
/// words (`rupaye`, `rupees`, `piso`, `pesos`). Number-word phrases are
/// matched *before* this list is applied, so a particle that is part of a
/// number — the `ka` in Cebuano `duha ka gatos` — is already consumed and is
/// never stripped out of the middle of an amount.
const Set<String> fillerTokens = <String>{
  // Particles and politeness.
  'ko',
  'ka',
  'na',
  'ne',
  'ang',
  'ng',
  'si',
  'kay',
  'po',
  'ni',
  'and',
  'the',
  'for',
  'of',
  'को',
  'का',
  'के',
  'की',
  // Spoken currency words.
  'rupaye',
  'rupaiya',
  'rupay',
  'rupee',
  'rupees',
  'piso',
  'peso',
  'pesos',
  'rs',
  'rs.',
  'रुपये',
  'रुपया',
  'ரூபாய்',
};

/// Punctuation stripped from the start and end of each token. Interior
/// characters are left alone so `1,200`, `200.50` and `kalim-an` survive.
const String _edgePunctuation = ' ,.!?;:()[]"\'‘’“”।';

/// A draft ledger entry read out of one spoken sentence.
///
/// Always treated as a suggestion. See the library doc comment above: the UI
/// must confirm it before anything is written to the ledger.
class ParsedEntry {
  const ParsedEntry({
    required this.transcript,
    required this.name,
    required this.amount,
    required this.item,
    required this.confidence,
    required this.amountSource,
    this.language,
    this.nameGuessedAfterAmount = false,
  });

  /// Nothing usable was heard.
  factory ParsedEntry.empty(String transcript) => ParsedEntry(
    transcript: transcript,
    name: '',
    amount: null,
    item: '',
    confidence: 0,
    amountSource: AmountSource.none,
  );

  /// What the speech engine returned, verbatim, kept with the draft so the
  /// shopkeeper can see what the phone thought it heard.
  final String transcript;

  /// The customer's name as spoken, or `''` when no name was heard.
  final String name;

  /// The amount in minor units (paise / centavos), or `null` when no amount
  /// was found. Never negative.
  final int? amount;

  /// The goods, as spoken, or `''` when nothing was named.
  final String item;

  /// 0.0 .. 1.0. See the weights above for how it is built.
  final double confidence;

  /// How the amount was read.
  final AmountSource amountSource;

  /// Which number-word table matched, when the amount came from words.
  final UtteranceLanguage? language;

  /// True when the amount was spoken first and the name had to be taken from
  /// the words after it, which is a guess.
  final bool nameGuessedAfterAmount;

  /// Whether an amount was found at all.
  bool get hasAmount => amount != null;

  /// Always true. A parsed utterance is never saved without a human tap.
  bool get needsConfirmation => true;

  /// Convenience band for the confirmation screen.
  ConfidenceBand get band => confidenceBand(confidence);

  @override
  String toString() =>
      'ParsedEntry(name: $name, amount: $amount, item: $item, '
      'confidence: ${confidence.toStringAsFixed(2)}, source: ${amountSource.name})';
}

/// Internal: one token, kept in both its original and normalised form.
class _Token {
  _Token(this.raw, this.norm);

  /// Original spelling, minus edge punctuation. Used to rebuild name and item.
  final String raw;

  /// Lower-cased, used for every lookup.
  final String norm;
}

List<_Token> _tokenize(String transcript) {
  final out = <_Token>[];
  for (final piece in transcript.split(RegExp(r'\s+'))) {
    final raw = _trimEdges(piece);
    if (raw.isEmpty) continue;
    out.add(_Token(raw, raw.toLowerCase()));
  }
  return out;
}

String _trimEdges(String s) {
  var start = 0;
  var end = s.length;
  while (start < end && _edgePunctuation.contains(s[start])) {
    start++;
  }
  while (end > start && _edgePunctuation.contains(s[end - 1])) {
    end--;
  }
  return s.substring(start, end);
}

/// Internal: an amount found in the token list, and the span it occupies.
class _AmountHit {
  _AmountHit(this.minor, this.source, this.start, this.end, this.language);

  final int minor;
  final AmountSource source;
  final int start; // inclusive
  final int end; // exclusive
  final UtteranceLanguage? language;
}

/// Finds the amount in [tokens].
///
/// The amount may sit anywhere in the sentence — first, last or in the middle.
/// Nothing here assumes it is the second word.
///
/// Digits are searched for first, across the whole sentence, before any number
/// word is considered. A recogniser that heard a number writes it as digits,
/// so digits are the stronger signal: in "Ramu do 200 tel" the `200` is the
/// amount and the English "do" is not Hindi for two.
_AmountHit? _findAmount(List<_Token> tokens) {
  for (var i = 0; i < tokens.length; i++) {
    final digits = parseMoneyDigits(tokens[i].raw);
    if (digits != null) {
      return _AmountHit(digits, AmountSource.digits, i, i + 1, null);
    }
  }

  for (var i = 0; i < tokens.length; i++) {
    final match = _matchAt(tokens, i);
    if (match == null) continue;

    // Additive chain: spoken numbers in all four languages add from large to
    // small ("ek hazaar do sau pachaas" = 1250). Keep absorbing the next
    // number-word phrase while each new value is strictly smaller than the
    // last one absorbed. Only word amounts chain — chaining after digits would
    // turn "200 do number atta" into 202.
    var total = match.value;
    var last = match.value;
    var end = i + match.tokenLength;
    var absorbed = 0;
    while (absorbed++ < 3) {
      final next = _matchAt(tokens, end);
      if (next == null || next.value >= last) break;
      total += next.value;
      last = next.value;
      end += next.tokenLength;
    }

    final minor = total * Currency.minorUnitsPerMajor;
    // Unreachable with the current tables, where the largest chain is a few
    // thousand; here so that extending a table can never produce a bad amount.
    if (minor > maxAmountMinor) continue;
    return _AmountHit(minor, AmountSource.numberWords, i, end, match.language);
  }
  return null;
}

/// The longest number-word phrase starting exactly at [index], or `null`, so
/// that "do sau" (200) always beats "do" (2).
NumberWordMatch? _matchAt(List<_Token> tokens, int index) {
  for (var len = maxNumberWordTokens; len >= 1; len--) {
    if (index + len > tokens.length) continue;
    final phrase = tokens
        .sublist(index, index + len)
        .map((t) => t.norm)
        .join(' ');
    final match = lookupNumberWord(phrase);
    if (match != null) return match;
  }
  return null;
}

List<String> _withoutFiller(List<_Token> tokens) => tokens
    .where((t) => !fillerTokens.contains(t.norm))
    .map((t) => t.raw)
    .toList();

/// Reads one spoken sentence into a draft ledger entry.
///
/// The rules, in order:
/// 1. Split on whitespace; strip punctuation from the edges of each token.
/// 2. Find the leftmost amount — digits anywhere, else the longest number-word
///    phrase, extended by any smaller number words that follow it.
/// 3. The **name** is the tokens before the amount, with filler removed, so
///    "Ramu bhai 200 tel" keeps the whole name.
/// 4. The **item** is the tokens after the amount, with filler removed.
/// 5. If the amount came last and more than one word stood before it, only the
///    first of those words is the name and the rest are the goods: an
///    amount-last sentence names the goods before the number ("Ramu tel 200").
/// 6. If nothing stood before the amount, the first word after it is taken as
///    the name and the rest as the item, and confidence drops to say so —
///    "200 Ramu cooking oil" is as common as "Ramu 200 cooking oil".
/// 7. If no amount was found at all, the first word becomes the name and the
///    rest the item, so the shopkeeper only has to fill in the number.
///
/// Never throws. Gibberish and empty input come back as a low-confidence draft.
ParsedEntry parseUtterance(String transcript) {
  if (transcript.trim().isEmpty) return ParsedEntry.empty(transcript);

  final tokens = _tokenize(transcript);
  if (tokens.isEmpty) return ParsedEntry.empty(transcript);

  final hit = _findAmount(tokens);

  if (hit == null) {
    // Rule 7: no number anywhere. Keep whatever words there are so the name
    // field is pre-filled and only the amount has to be typed.
    final words = _withoutFiller(tokens);
    final name = words.isEmpty ? '' : words.first;
    final item = words.length > 1 ? words.sublist(1).join(' ') : '';
    var confidence = confidenceNoAmount;
    if (name.isNotEmpty) confidence += confidenceWordsBonus;
    return ParsedEntry(
      transcript: transcript,
      name: name,
      amount: null,
      item: item,
      confidence: _clamp(confidence),
      amountSource: AmountSource.none,
    );
  }

  final before = _withoutFiller(tokens.sublist(0, hit.start));
  final after = _withoutFiller(tokens.sublist(hit.end));

  String name;
  String item;
  var guessed = false;

  if (before.isEmpty && after.isNotEmpty) {
    // Rule 6: amount spoken first, so the name has to come from after it.
    name = after.first;
    item = after.length > 1 ? after.sublist(1).join(' ') : '';
    guessed = true;
  } else if (after.isEmpty && before.length > 1) {
    // Rule 5: amount spoken last, so the goods are in front of it.
    name = before.first;
    item = before.sublist(1).join(' ');
  } else {
    name = before.join(' ');
    item = after.join(' ');
  }

  var confidence = confidenceAmountFound;
  confidence += hit.source == AmountSource.digits
      ? confidenceDigitsBonus
      : confidenceWordsBonus;
  if (name.isNotEmpty) {
    confidence += guessed ? confidenceNameGuessed : confidenceNameFound;
  }
  if (item.isNotEmpty) confidence += confidenceItemFound;

  return ParsedEntry(
    transcript: transcript,
    name: name,
    amount: hit.minor,
    item: item,
    confidence: _clamp(confidence),
    amountSource: hit.source,
    language: hit.language,
    nameGuessedAfterAmount: guessed,
  );
}

double _clamp(double v) => v < 0
    ? 0
    : v > 1
    ? 1
    : v;
