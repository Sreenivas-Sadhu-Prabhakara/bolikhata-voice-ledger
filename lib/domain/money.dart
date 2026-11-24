/// Money handling for the credit ledger.
///
/// Every amount in this app is a whole number of **minor units** held in an
/// `int` — paise for Indian rupees, centavos for Philippine pesos. Integers are
/// used instead of `double` so that adding and subtracting a long list of
/// ledger entries can never drift by a fraction of a paise.
///
/// Pure Dart: nothing in `lib/domain/` imports Flutter.
library;

/// How a currency groups the digits to the left of the decimal point.
enum DigitGrouping {
  /// Last three digits, then groups of two: `12,34,567`.
  indian,

  /// Groups of three: `1,234,567`.
  western,
}

/// The two currencies this ledger supports.
///
/// Both have 100 minor units to one major unit, so a transcript saying
/// "two hundred" means the same number of minor units in either.
enum Currency {
  inr('INR', '₹', DigitGrouping.indian),
  php('PHP', '₱', DigitGrouping.western);

  const Currency(this.code, this.symbol, this.grouping);

  /// ISO 4217 code, e.g. `INR`.
  final String code;

  /// Display symbol, e.g. `₹`.
  final String symbol;

  /// Digit grouping convention used when formatting.
  final DigitGrouping grouping;

  /// Minor units in one major unit. 100 for both supported currencies.
  static const int minorUnitsPerMajor = 100;

  /// Parses a stored currency code, falling back to [Currency.inr].
  static Currency fromCode(String? code) {
    for (final c in Currency.values) {
      if (c.code == code) return c;
    }
    return Currency.inr;
  }
}

/// Currency symbols and spoken currency words that are stripped before a
/// number is read out of a transcript.
///
/// Kept here next to [Currency] so there is one place to add a currency.
const List<String> currencyMarkers = <String>[
  '₹', // ₹
  '₱', // ₱
  'rs.',
  'rs',
  'inr',
  'php',
  'p', // "P200", a common written shorthand for pesos
];

/// Groups [digits] (a string of `0`-`9` only) according to [grouping].
String groupDigits(String digits, DigitGrouping grouping) {
  if (digits.length <= 3) return digits;
  switch (grouping) {
    case DigitGrouping.western:
      return _groupFromRight(digits, 3);
    case DigitGrouping.indian:
      final last3 = digits.substring(digits.length - 3);
      final rest = digits.substring(0, digits.length - 3);
      return '${_groupFromRight(rest, 2)},$last3';
  }
}

String _groupFromRight(String digits, int size) {
  final out = <String>[];
  var end = digits.length;
  while (end > size) {
    out.insert(0, digits.substring(end - size, end));
    end -= size;
  }
  out.insert(0, digits.substring(0, end));
  return out.join(',');
}

/// Formats [minor] minor units for display, e.g. `₹1,200` or `₱200.50`.
///
/// The fractional part is shown only when it is non-zero, because a shop
/// ledger is overwhelmingly whole rupees and pesos. A negative amount keeps
/// its minus sign; use [formatMoneyAbs] when the sign is carried by the words
/// around the number instead.
String formatMoney(int minor, Currency currency, {bool withSymbol = true}) {
  final negative = minor < 0;
  final abs = negative ? -minor : minor;
  final major = abs ~/ Currency.minorUnitsPerMajor;
  final frac = abs % Currency.minorUnitsPerMajor;
  final body = StringBuffer()
    ..write(groupDigits(major.toString(), currency.grouping));
  if (frac != 0) {
    body.write('.');
    body.write(frac.toString().padLeft(2, '0'));
  }
  final symbol = withSymbol ? currency.symbol : '';
  return '${negative ? '-' : ''}$symbol$body';
}

/// Formats the size of [minor] without a sign, e.g. `₹50` for `-5000`.
String formatMoneyAbs(int minor, Currency currency, {bool withSymbol = true}) =>
    formatMoney(minor < 0 ? -minor : minor, currency, withSymbol: withSymbol);

/// Renders [minor] for a text field the shopkeeper is about to edit: `200`
/// when the amount is whole, `200.50` when it is not.
///
/// No symbol and no grouping, so whatever comes back out of the field can be
/// read straight back by [parseMoneyDigits].
String minorToInputString(int minor) {
  final negative = minor < 0;
  final abs = negative ? -minor : minor;
  final major = abs ~/ Currency.minorUnitsPerMajor;
  final frac = abs % Currency.minorUnitsPerMajor;
  final body = frac == 0
      ? '$major'
      : '$major.${frac.toString().padLeft(2, '0')}';
  return '${negative ? '-' : ''}$body';
}

/// Renders [minor] as a plain decimal string such as `200.00`, for export
/// files that a spreadsheet has to read back as a number.
String minorToDecimalString(int minor) {
  final negative = minor < 0;
  final abs = negative ? -minor : minor;
  final major = abs ~/ Currency.minorUnitsPerMajor;
  final frac = (abs % Currency.minorUnitsPerMajor).toString().padLeft(2, '0');
  return '${negative ? '-' : ''}$major.$frac';
}

/// The largest amount a single ledger line may hold: ₹/₱ 1,00,00,00,000 in
/// minor units.
///
/// Anything bigger is a mis-heard transcript or a slipped finger, not a shop
/// credit line. The cap also keeps a long digit run from overflowing an `int`
/// when it is multiplied up to minor units.
const int maxAmountMinor = 100000000000;

/// Reads an amount written in digits and returns it in minor units, or `null`
/// if [raw] is not a number.
///
/// Accepts the shapes that turn up in a transcript or in a typed correction:
/// `200`, `1,200`, `₹200`, `Rs 200` (the `Rs` arrives as its own token and is
/// stripped by the caller), `₱200.50`, `200/-`. At most two decimal places are
/// kept; a longer fraction is rejected rather than silently rounded, and
/// anything over [maxAmountMinor] is rejected too.
int? parseMoneyDigits(String raw) {
  var s = raw.trim().toLowerCase();
  if (s.isEmpty) return null;

  // Strip currency symbols and the "/-" that Indian shop slips use.
  for (final marker in currencyMarkers) {
    if (s.startsWith(marker)) {
      s = s.substring(marker.length);
      break;
    }
  }
  if (s.endsWith('/-')) s = s.substring(0, s.length - 2);
  if (s.endsWith('/')) s = s.substring(0, s.length - 1);
  s = s.replaceAll(',', '').trim();
  if (s.isEmpty) return null;

  final match = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$').firstMatch(s);
  if (match == null) return null;

  final major = int.tryParse(match.group(1)!);
  if (major == null) return null; // absurdly long digit run
  if (major > maxAmountMinor ~/ Currency.minorUnitsPerMajor) return null;
  final fracText = match.group(2);
  final frac = fracText == null ? 0 : int.parse(fracText.padRight(2, '0'));
  return major * Currency.minorUnitsPerMajor + frac;
}
