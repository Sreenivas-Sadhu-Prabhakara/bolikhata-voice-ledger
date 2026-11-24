import 'package:bolikhata/domain/export.dart';
import 'package:bolikhata/domain/ledger.dart';
import 'package:bolikhata/domain/money.dart';
import 'package:flutter_test/flutter_test.dart';

final DateTime day1 = DateTime(2026, 1, 10, 9, 5);
final DateTime day2 = DateTime(2026, 1, 11, 18, 30);

const Customer ramu = Customer(id: 'c1', name: 'Ramu');
const Customer nena = Customer(id: 'c2', name: 'Nena, Aling');

void main() {
  group('csvEscape', () {
    const cases = <(String, String)>[
      ('', ''),
      ('tel', 'tel'),
      ('cooking oil', 'cooking oil'),
      ('Nena, Aling', '"Nena, Aling"'),
      ('say "hello"', '"say ""hello"""'),
      ('two\nlines', '"two\nlines"'),
      ('carriage\rreturn', '"carriage\rreturn"'),
      ('तेल', 'तेल'),
      ('तेल, 1 litre', '"तेल, 1 litre"'),
    ];

    for (final (raw, expected) in cases) {
      test('"$raw" escapes to "$expected"', () {
        expect(csvEscape(raw), expected);
      });
    }
  });

  group('exportCsv', () {
    test('an empty book is just the header', () {
      final csv = exportCsv(Ledger.empty);
      expect(csv.trim().split('\n'), hasLength(1));
      expect(csv, startsWith('date,time,customer,type,amount_inr,'));
      expect(csv, endsWith('\n'));
    });

    test('the header names the shop currency', () {
      expect(
        exportCsv(const Ledger(currency: Currency.php)),
        contains('amount_php'),
      );
    });

    test('one row per line in the book, oldest first', () {
      final book = Ledger(
        customers: const <Customer>[ramu, nena],
        entries: <LedgerEntry>[
          LedgerEntry(
            id: 'e2',
            customerId: nena.id,
            kind: EntryKind.paymentReceived,
            amount: 5000,
            at: day2,
          ),
          LedgerEntry(
            id: 'e1',
            customerId: ramu.id,
            kind: EntryKind.creditGiven,
            amount: 20050,
            at: day1,
            item: 'cooking oil',
            transcript: 'Ramu, 200.50, cooking oil',
          ),
        ],
      );

      final lines = exportCsv(book).trim().split('\n');
      expect(lines, hasLength(3));
      expect(
        lines[1],
        '2026-01-10,09:05,Ramu,credit,200.50,200.50,cooking oil,'
        '"Ramu, 200.50, cooking oil"',
      );
      expect(lines[2], '2026-01-11,18:30,"Nena, Aling",payment,50.00,-50.00,,');
    });

    test(
      'a payment carries a positive amount and a negative signed amount',
      () {
        final book = Ledger(
          customers: const <Customer>[ramu],
          entries: <LedgerEntry>[
            LedgerEntry(
              id: 'e1',
              customerId: ramu.id,
              kind: EntryKind.paymentReceived,
              amount: 20000,
              at: day1,
            ),
          ],
        );
        expect(exportCsv(book), contains(',payment,200.00,-200.00,'));
      },
    );

    test('an entry whose customer is missing still exports', () {
      final book = Ledger(
        customers: const <Customer>[],
        entries: <LedgerEntry>[
          LedgerEntry(
            id: 'e1',
            customerId: 'ghost',
            kind: EntryKind.creditGiven,
            amount: 100,
            at: day1,
          ),
        ],
      );
      expect(exportCsv(book), contains(',ghost,credit,1.00,'));
    });
  });

  group('exportSummary', () {
    test('an empty book says so', () {
      final text = exportSummary(Ledger.empty);
      expect(text, contains('Credit book'));
      expect(text, contains('Outstanding: ₹0'));
      expect(text, contains('No customers yet.'));
      expect(text, isNot(contains('Advances held')));
    });

    test('names the shop when it is set', () {
      expect(
        exportSummary(const Ledger(shopName: 'Ramu Kirana')),
        startsWith('Ramu Kirana — credit book'),
      );
    });

    test('lists each customer, biggest debtor first', () {
      final book = Ledger(
        customers: const <Customer>[ramu, nena],
        entries: <LedgerEntry>[
          LedgerEntry(
            id: 'e1',
            customerId: ramu.id,
            kind: EntryKind.creditGiven,
            amount: 20000,
            at: day1,
          ),
          LedgerEntry(
            id: 'e2',
            customerId: nena.id,
            kind: EntryKind.creditGiven,
            amount: 70000,
            at: day1,
          ),
        ],
        currency: Currency.php,
      );
      final lines = exportSummary(book).trim().split('\n');
      expect(lines.first, 'Credit book');
      expect(lines[1], 'Outstanding: ₱900');
      expect(lines[3], 'Nena, Aling: ₱700 pending (1 entry)');
      expect(lines[4], 'Ramu: ₱200 pending (1 entry)');
    });

    test('reports advances separately and never as money owed', () {
      final book = Ledger(
        customers: const <Customer>[ramu, nena],
        entries: <LedgerEntry>[
          LedgerEntry(
            id: 'e1',
            customerId: ramu.id,
            kind: EntryKind.creditGiven,
            amount: 20000,
            at: day1,
          ),
          LedgerEntry(
            id: 'e2',
            customerId: nena.id,
            kind: EntryKind.paymentReceived,
            amount: 30000,
            at: day1,
          ),
        ],
      );
      final text = exportSummary(book);
      expect(text, contains('Outstanding: ₹200'));
      expect(text, contains('Advances held: ₹300'));
      expect(text, contains('Nena, Aling: ₹300 in advance (1 entry)'));
      expect(text, isNot(contains('-₹')));
    });

    test('a settled customer is shown as settled', () {
      final book = Ledger(
        customers: const <Customer>[ramu],
        entries: <LedgerEntry>[
          LedgerEntry(
            id: 'e1',
            customerId: ramu.id,
            kind: EntryKind.creditGiven,
            amount: 20000,
            at: day1,
          ),
          LedgerEntry(
            id: 'e2',
            customerId: ramu.id,
            kind: EntryKind.paymentReceived,
            amount: 20000,
            at: day2,
          ),
        ],
      );
      expect(exportSummary(book), contains('Ramu: settled (2 entries)'));
    });
  });
}
