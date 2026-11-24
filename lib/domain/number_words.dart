/// Spoken number words, for the languages a shopkeeper is most likely to use.
///
/// These tables are deliberately **modest**. They cover the small numbers, the
/// hundreds and the thousands that a shop credit entry actually uses — not the
/// whole number system of any language. Each language lives in exactly one
/// named map so a new word, spelling or language is a one-line change.
///
/// A key is a **phrase**: one or more whitespace-separated, lower-cased tokens
/// exactly as they appear in a transcript. Both the romanised spelling (what an
/// English-locale recogniser usually returns) and the native script (what a
/// Hindi or Tamil locale returns) are listed, because the same shopkeeper gets
/// either depending on the phone's speech settings.
///
/// Values are in **major** units (200 means two hundred rupees or pesos); the
/// parser multiplies them up to minor units.
///
/// Pure Dart: nothing in `lib/domain/` imports Flutter.
library;

/// The languages whose number words are recognised.
enum UtteranceLanguage {
  hindi('Hindi'),
  tamil('Tamil'),
  tagalog('Tagalog'),
  cebuano('Cebuano');

  const UtteranceLanguage(this.label);

  /// English name, for showing which table matched.
  final String label;
}

/// Hindi number words, romanised and in Devanagari.
const Map<String, int> hindiNumberWords = <String, int>{
  // Romanised, as an English-locale recogniser tends to return them.
  'ek': 1,
  'do': 2,
  'teen': 3,
  'char': 4,
  'chaar': 4,
  'paanch': 5,
  'panch': 5,
  'chhe': 6,
  'chah': 6,
  'saat': 7,
  'aath': 8,
  'nau': 9,
  'das': 10,
  'bees': 20,
  'pachaas': 50,
  'pachas': 50,
  'sau': 100,
  'ek sau': 100,
  'do sau': 200,
  'teen sau': 300,
  'char sau': 400,
  'chaar sau': 400,
  'paanch sau': 500,
  'panch sau': 500,
  'hazaar': 1000,
  'hazar': 1000,
  'ek hazaar': 1000,
  'ek hazar': 1000,
  'do hazaar': 2000,
  'do hazar': 2000,
  'paanch hazaar': 5000,
  // Devanagari, as a hi-IN recogniser returns them.
  'एक': 1,
  'दो': 2,
  'तीन': 3,
  'चार': 4,
  'पाँच': 5,
  'पांच': 5,
  'दस': 10,
  'बीस': 20,
  'पचास': 50,
  'सौ': 100,
  'एक सौ': 100,
  'दो सौ': 200,
  'तीन सौ': 300,
  'पाँच सौ': 500,
  'पांच सौ': 500,
  'हजार': 1000,
  'हज़ार': 1000,
  'एक हजार': 1000,
  'एक हज़ार': 1000,
  'दो हजार': 2000,
};

/// Tamil number words, romanised and in Tamil script.
const Map<String, int> tamilNumberWords = <String, int>{
  // Romanised.
  'onru': 1,
  'ondru': 1,
  'irandu': 2,
  'rendu': 2,
  'moondru': 3,
  'moonu': 3,
  'naangu': 4,
  'ainthu': 5,
  'anju': 5,
  'aaru': 6,
  'ezhu': 7,
  'ettu': 8,
  'onpathu': 9,
  'pathu': 10,
  'irupathu': 20,
  'aimbathu': 50,
  'nooru': 100,
  'irunooru': 200,
  'munnooru': 300,
  'ainooru': 500,
  'aiynooru': 500,
  'aayiram': 1000,
  'rendaayiram': 2000,
  'ainthaayiram': 5000,
  // Tamil script.
  'ஒன்று': 1,
  'இரண்டு': 2,
  'மூன்று': 3,
  'ஐந்து': 5,
  'பத்து': 10,
  'ஐம்பது': 50,
  'நூறு': 100,
  'இருநூறு': 200,
  'முந்நூறு': 300,
  'ஐந்நூறு': 500,
  'ஆயிரம்': 1000,
};

/// Tagalog number words.
const Map<String, int> tagalogNumberWords = <String, int>{
  'isa': 1,
  'dalawa': 2,
  'tatlo': 3,
  'apat': 4,
  'lima': 5,
  'anim': 6,
  'pito': 7,
  'walo': 8,
  'siyam': 9,
  'sampu': 10,
  'dalawampu': 20,
  'limampu': 50,
  'daan': 100,
  'sandaan': 100,
  'isang daan': 100,
  'dalawang daan': 200,
  'dalawandaan': 200,
  'tatlong daan': 300,
  'apat na daan': 400,
  'limang daan': 500,
  'libo': 1000,
  'sanlibo': 1000,
  'isang libo': 1000,
  'dalawang libo': 2000,
  'limang libo': 5000,
};

/// Cebuano (Bisaya) number words.
const Map<String, int> cebuanoNumberWords = <String, int>{
  'usa': 1,
  'duha': 2,
  'tulo': 3,
  'upat': 4,
  'lima': 5,
  'unom': 6,
  'pito': 7,
  'walo': 8,
  'siyam': 9,
  'napulo': 10,
  'kalim-an': 50,
  'gatos': 100,
  'usa ka gatos': 100,
  'duha ka gatos': 200,
  'tulo ka gatos': 300,
  'lima ka gatos': 500,
  'libo': 1000,
  'usa ka libo': 1000,
  'duha ka libo': 2000,
  'lima ka libo': 5000,
};

/// Every table, keyed by language. Iteration order is the lookup order.
const Map<UtteranceLanguage, Map<String, int>> numberWordTables =
    <UtteranceLanguage, Map<String, int>>{
      UtteranceLanguage.hindi: hindiNumberWords,
      UtteranceLanguage.tamil: tamilNumberWords,
      UtteranceLanguage.tagalog: tagalogNumberWords,
      UtteranceLanguage.cebuano: cebuanoNumberWords,
    };

/// A number word phrase that matched, and where it came from.
class NumberWordMatch {
  const NumberWordMatch(this.phrase, this.value, this.language);

  /// The phrase as it appears in the table, e.g. `duha ka gatos`.
  final String phrase;

  /// Value in major units, e.g. 200.
  final int value;

  /// The table the phrase was found in.
  final UtteranceLanguage language;

  /// Number of whitespace-separated tokens the phrase spans.
  int get tokenLength => phrase.split(' ').length;
}

Map<String, NumberWordMatch> _buildIndex() {
  final index = <String, NumberWordMatch>{};
  for (final entry in numberWordTables.entries) {
    for (final word in entry.value.entries) {
      // First table wins when two languages share a spelling. Shared
      // spellings (`lima`, `libo`, `pito`) carry the same value in both, which
      // `number_words_test.dart` asserts.
      index.putIfAbsent(
        word.key,
        () => NumberWordMatch(word.key, word.value, entry.key),
      );
    }
  }
  return Map<String, NumberWordMatch>.unmodifiable(index);
}

/// All tables merged into one phrase lookup.
final Map<String, NumberWordMatch> numberWordIndex = _buildIndex();

/// The longest phrase in any table, in tokens. The parser never has to look
/// further ahead than this.
final int maxNumberWordTokens = numberWordIndex.values
    .map((m) => m.tokenLength)
    .fold(1, (a, b) => a > b ? a : b);

/// Looks up a lower-cased phrase such as `do sau`, or returns `null`.
NumberWordMatch? lookupNumberWord(String phrase) => numberWordIndex[phrase];
