/// Manual export of the book.
///
/// There is no cloud backup in this app, so this is the backup: the shopkeeper
/// taps export and gets the whole book as text they can keep, mail to
/// themselves or hand to an accountant. Producing the text is pure; handing it
/// to the share sheet is the UI's job.
///
/// Pure Dart: nothing in `lib/domain/` imports Flutter.
library;

import 'dates.dart';
import 'ledger.dart';
import 'money.dart';

/// Quotes a CSV field when it contains a comma, a quote or a line break, and
/// doubles any embedded quotes, per RFC 4180.
String csvEscape(String field) {
  final needsQuotes =
      field.contains(',') ||
      field.contains('"') ||
      field.contains('\n') ||
      field.contains('\r');
  if (!needsQuotes) return field;
  return '"${field.replaceAll('"', '""')}"';
}

/// The whole book as CSV, oldest entry first, one row per line in the book.
///
/// Amounts are plain decimals with no currency symbol so a spreadsheet reads
/// them as numbers; the currency is named in the header row instead. A credit
/// row and a payment row both carry a positive `amount`, with the direction in
/// the `type` column, and `signed_amount` carries the value that sums to a
/// balance.
String exportCsv(Ledger ledger) {
  final rows = <String>[
    'date,time,customer,type,amount_${ledger.currency.code.toLowerCase()},'
        'signed_amount,item,heard',
  ];
  final sorted = ledger.entries.toList()..sort((a, b) => a.at.compareTo(b.at));
  for (final e in sorted) {
    final customer = ledger.customerById(e.customerId)?.name ?? e.customerId;
    rows.add(
      <String>[
        formatDate(e.at),
        formatTime(e.at),
        csvEscape(customer),
        e.kind.code,
        minorToDecimalString(e.amount),
        minorToDecimalString(e.signedAmount),
        csvEscape(e.item),
        csvEscape(e.transcript),
      ].join(','),
    );
  }
  return '${rows.join('\n')}\n';
}

/// A short plain-text statement of where every customer stands, for sharing in
/// a chat or pasting into a message.
String exportSummary(Ledger ledger) {
  final c = ledger.currency;
  final lines = <String>[
    if (ledger.shopName != null && ledger.shopName!.isNotEmpty)
      '${ledger.shopName} — credit book',
    if (ledger.shopName == null || ledger.shopName!.isEmpty) 'Credit book',
    'Outstanding: ${formatMoney(ledger.totalOutstanding(), c)}',
  ];
  final advance = ledger.totalAdvance();
  if (advance > 0) {
    lines.add('Advances held: ${formatMoney(advance, c)}');
  }
  lines.add('');
  final balances = ledger.balances();
  if (balances.isEmpty) {
    lines.add('No customers yet.');
  }
  for (final b in balances) {
    final state = b.owes
        ? '${formatMoney(b.balance, c)} pending'
        : b.settled
        ? 'settled'
        : '${formatMoneyAbs(b.balance, c)} in advance';
    final count = b.entryCount == 1 ? '1 entry' : '${b.entryCount} entries';
    lines.add('${b.customer.name}: $state ($count)');
  }
  return '${lines.join('\n')}\n';
}
