import 'dart:convert';

import 'package:bolikhata/domain/ledger.dart';
import 'package:bolikhata/domain/money.dart';
import 'package:flutter_test/flutter_test.dart';

final DateTime day1 = DateTime(2026, 1, 10, 9, 30);
final DateTime day2 = DateTime(2026, 1, 11, 18, 5);
final DateTime day3 = DateTime(2026, 2, 1, 7, 15);

const Customer ramu = Customer(id: 'c1', name: 'Ramu');
const Customer nena = Customer(id: 'c2', name: 'Nena');
const Customer dodong = Customer(id: 'c3', name: 'Dodong');

LedgerEntry credit(
  String id,
  Customer customer,
  int minor, {
  DateTime? at,
  String item = '',
}) => LedgerEntry(
  id: id,
  customerId: customer.id,
  kind: EntryKind.creditGiven,
  amount: minor,
  at: at ?? day1,
  item: item,
);

LedgerEntry payment(String id, Customer customer, int minor, {DateTime? at}) =>
    LedgerEntry(
      id: id,
      customerId: customer.id,
      kind: EntryKind.paymentReceived,
      amount: minor,
      at: at ?? day2,
    );

void main() {
  group('balanceFor', () {
    // (description, entries, expected balance for Ramu)
    final cases = <(String, List<LedgerEntry>, int)>[
      ('no entries at all is zero', <LedgerEntry>[], 0),
      ('one credit', <LedgerEntry>[credit('e1', ramu, 20000)], 20000),
      (
        'two credits add up',
        <LedgerEntry>[credit('e1', ramu, 20000), credit('e2', ramu, 5050)],
        25050,
      ),
      (
        'a payment comes off',
        <LedgerEntry>[credit('e1', ramu, 20000), payment('e2', ramu, 5000)],
        15000,
      ),
      (
        'exact settlement is exactly zero',
        <LedgerEntry>[credit('e1', ramu, 20000), payment('e2', ramu, 20000)],
        0,
      ),
      (
        'settlement over many lines is exactly zero',
        <LedgerEntry>[
          credit('e1', ramu, 3333),
          credit('e2', ramu, 3333),
          credit('e3', ramu, 3334),
          payment('e4', ramu, 10000),
        ],
        0,
      ),
      (
        'overpayment becomes a negative advance',
        <LedgerEntry>[credit('e1', ramu, 20000), payment('e2', ramu, 25000)],
        -5000,
      ),
      (
        'a payment with no credit at all is an advance',
        <LedgerEntry>[payment('e1', ramu, 10000)],
        -10000,
      ),
      (
        'large values do not drift',
        <LedgerEntry>[
          credit('e1', ramu, 999999999),
          credit('e2', ramu, 999999999),
          payment('e3', ramu, 1999999998),
        ],
        0,
      ),
      (
        'another customer never leaks in',
        <LedgerEntry>[credit('e1', ramu, 20000), credit('e2', nena, 70000)],
        20000,
      ),
    ];

    for (final (what, entries, expected) in cases) {
      test(what, () {
        final ledger = Ledger(
          customers: const <Customer>[ramu, nena],
          entries: entries,
        );
        expect(ledger.balanceFor(ramu.id), expected);
      });
    }

    test('an unknown customer id is zero, not an error', () {
      final ledger = Ledger(
        customers: const <Customer>[ramu],
        entries: <LedgerEntry>[credit('e1', ramu, 20000)],
      );
      expect(ledger.balanceFor('nobody'), 0);
      expect(ledger.balanceFor(''), 0);
    });

    test('an entry amount must be positive', () {
      expect(
        () => LedgerEntry(
          id: 'x',
          customerId: 'c1',
          kind: EntryKind.creditGiven,
          amount: 0,
          at: day1,
        ),
        throwsArgumentError,
      );
      expect(
        () => LedgerEntry(
          id: 'x',
          customerId: 'c1',
          kind: EntryKind.paymentReceived,
          amount: -100,
          at: day1,
        ),
        throwsArgumentError,
      );
      expect(
        () => LedgerEntry(
          id: 'x',
          customerId: '',
          kind: EntryKind.creditGiven,
          amount: 100,
          at: day1,
        ),
        throwsArgumentError,
      );
    });

    test('the sign lives in the kind, never in the amount', () {
      expect(credit('e1', ramu, 20000).signedAmount, 20000);
      expect(payment('e2', ramu, 20000).signedAmount, -20000);
    });
  });

  group('totalOutstanding and totalAdvance', () {
    test('an empty book is zero on both', () {
      expect(Ledger.empty.totalOutstanding(), 0);
      expect(Ledger.empty.totalAdvance(), 0);
    });

    test('customers with no entries are zero on both', () {
      const ledger = Ledger(customers: <Customer>[ramu, nena]);
      expect(ledger.totalOutstanding(), 0);
      expect(ledger.totalAdvance(), 0);
    });

    test('outstanding sums what is owed', () {
      final ledger = Ledger(
        customers: const <Customer>[ramu, nena],
        entries: <LedgerEntry>[
          credit('e1', ramu, 20000),
          credit('e2', nena, 70000),
          payment('e3', nena, 10000),
        ],
      );
      expect(ledger.totalOutstanding(), 80000);
      expect(ledger.totalAdvance(), 0);
    });

    test('a settled customer adds nothing', () {
      final ledger = Ledger(
        customers: const <Customer>[ramu, nena],
        entries: <LedgerEntry>[
          credit('e1', ramu, 20000),
          payment('e2', ramu, 20000),
          credit('e3', nena, 5000),
        ],
      );
      expect(ledger.totalOutstanding(), 5000);
      expect(ledger.totalAdvance(), 0);
    });

    test('an advance is reported separately, never netted off a debt', () {
      final ledger = Ledger(
        customers: const <Customer>[ramu, nena],
        entries: <LedgerEntry>[
          credit('e1', ramu, 20000), // Ramu owes 200
          payment('e2', nena, 30000), // Nena is 300 in advance
        ],
      );
      // The money out on the street is still 200, not -100.
      expect(ledger.totalOutstanding(), 20000);
      expect(ledger.totalAdvance(), 30000);
    });

    test('advances are reported as a positive number', () {
      final ledger = Ledger(
        customers: const <Customer>[ramu, nena],
        entries: <LedgerEntry>[
          payment('e1', ramu, 1000),
          payment('e2', nena, 2000),
        ],
      );
      expect(ledger.totalAdvance(), 3000);
      expect(ledger.totalOutstanding(), 0);
    });

    test('large values stay exact', () {
      final ledger = Ledger(
        customers: const <Customer>[ramu, nena],
        entries: <LedgerEntry>[
          credit('e1', ramu, 99999999999),
          credit('e2', nena, 1),
        ],
      );
      expect(ledger.totalOutstanding(), 100000000000);
      expect(
        formatMoney(ledger.totalOutstanding(), Currency.inr),
        '₹1,00,00,00,000',
      );
    });
  });

  group('balances() orders the biggest debtor first', () {
    test('descending by balance', () {
      final ledger = Ledger(
        customers: const <Customer>[ramu, nena, dodong],
        entries: <LedgerEntry>[
          credit('e1', ramu, 20000),
          credit('e2', nena, 70000),
          credit('e3', dodong, 5000),
        ],
      );
      expect(ledger.balances().map((b) => b.customer.name).toList(), <String>[
        'Nena',
        'Ramu',
        'Dodong',
      ]);
    });

    test('advances sink to the bottom', () {
      final ledger = Ledger(
        customers: const <Customer>[ramu, nena, dodong],
        entries: <LedgerEntry>[
          credit('e1', ramu, 20000),
          payment('e2', nena, 70000),
        ],
      );
      final names = ledger.balances().map((b) => b.customer.name).toList();
      expect(names, <String>['Ramu', 'Dodong', 'Nena']);
      expect(ledger.balances().first.owes, isTrue);
      expect(ledger.balances()[1].settled, isTrue);
      expect(ledger.balances().last.inAdvance, isTrue);
    });

    test('equal balances order by name, so the list never reshuffles', () {
      const zed = Customer(id: 'c9', name: 'zebra');
      const amy = Customer(id: 'c8', name: 'Amy');
      final ledger = Ledger(
        customers: const <Customer>[zed, amy],
        entries: <LedgerEntry>[credit('e1', zed, 100), credit('e2', amy, 100)],
      );
      expect(ledger.balances().map((b) => b.customer.name).toList(), <String>[
        'Amy',
        'zebra',
      ]);
    });

    test('carries the entry count and the last activity date', () {
      final ledger = Ledger(
        customers: const <Customer>[ramu, nena],
        entries: <LedgerEntry>[
          credit('e1', ramu, 100, at: day1),
          credit('e2', ramu, 100, at: day3),
          payment('e3', ramu, 50, at: day2),
        ],
      );
      final ramuRow = ledger.balances().firstWhere(
        (b) => b.customer.id == ramu.id,
      );
      expect(ramuRow.entryCount, 3);
      expect(ramuRow.lastActivity, day3);
      final nenaRow = ledger.balances().firstWhere(
        (b) => b.customer.id == nena.id,
      );
      expect(nenaRow.entryCount, 0);
      expect(nenaRow.lastActivity, isNull);
    });

    test('an empty book has no rows', () {
      expect(Ledger.empty.balances(), isEmpty);
    });
  });

  group('lookups', () {
    const ledger = Ledger(customers: <Customer>[ramu, nena]);

    test('by id', () {
      expect(ledger.customerById('c1'), ramu);
      expect(ledger.customerById('nope'), isNull);
    });

    test('by name, ignoring case and spaces', () {
      expect(ledger.customerByName('Ramu')?.id, 'c1');
      expect(ledger.customerByName('ramu')?.id, 'c1');
      expect(ledger.customerByName('  RAMU  ')?.id, 'c1');
      expect(ledger.customerByName('Ram'), isNull);
      expect(ledger.customerByName(''), isNull);
      expect(ledger.customerByName('   '), isNull);
    });

    test('entriesFor returns one page, newest first', () {
      final book = Ledger(
        customers: const <Customer>[ramu, nena],
        entries: <LedgerEntry>[
          credit('e1', ramu, 100, at: day1),
          credit('e2', nena, 100, at: day2),
          credit('e3', ramu, 100, at: day3),
        ],
      );
      expect(book.entriesFor(ramu.id).map((e) => e.id).toList(), <String>[
        'e3',
        'e1',
      ]);
      expect(book.entriesFor('nobody'), isEmpty);
    });
  });

  group('mutation returns a new book', () {
    test('withEntry leaves the original alone', () {
      const before = Ledger(customers: <Customer>[ramu]);
      final after = before.withEntry(credit('e1', ramu, 20000));
      expect(before.entries, isEmpty);
      expect(after.entries, hasLength(1));
      expect(after.balanceFor(ramu.id), 20000);
    });

    test('withCustomer appends, then replaces by id', () {
      final added = Ledger.empty.withCustomer(ramu);
      expect(added.customers, hasLength(1));
      final renamed = added.withCustomer(ramu.copyWith(name: 'Ramu Kaka'));
      expect(renamed.customers, hasLength(1));
      expect(renamed.customers.single.name, 'Ramu Kaka');
    });

    test('withoutEntry removes one line', () {
      final book = Ledger(
        customers: const <Customer>[ramu],
        entries: <LedgerEntry>[
          credit('e1', ramu, 20000),
          credit('e2', ramu, 10000),
        ],
      );
      expect(book.withoutEntry('e1').balanceFor(ramu.id), 10000);
      expect(book.withoutEntry('nope').balanceFor(ramu.id), 30000);
    });

    test('withoutCustomer takes their page with them', () {
      final book = Ledger(
        customers: const <Customer>[ramu, nena],
        entries: <LedgerEntry>[
          credit('e1', ramu, 20000),
          credit('e2', nena, 10000),
        ],
      );
      final after = book.withoutCustomer(ramu.id);
      expect(after.customers, hasLength(1));
      expect(after.entries, hasLength(1));
      expect(after.totalOutstanding(), 10000);
    });

    test('copyWith keeps what is not named', () {
      const book = Ledger(
        customers: <Customer>[ramu],
        currency: Currency.php,
        shopName: 'Nena Store',
      );
      final next = book.copyWith(currency: Currency.inr);
      expect(next.currency, Currency.inr);
      expect(next.shopName, 'Nena Store');
      expect(next.customers, hasLength(1));
    });
  });

  group('storage round trip', () {
    test('a full book survives JSON', () {
      final book = Ledger(
        customers: const <Customer>[
          Customer(id: 'c1', name: 'रामू', phone: '+910000000000'),
          nena,
        ],
        entries: <LedgerEntry>[
          LedgerEntry(
            id: 'e1',
            customerId: 'c1',
            kind: EntryKind.creditGiven,
            amount: 20050,
            at: day1,
            item: 'तेल, 1 litre',
            transcript: 'रामू दो सौ तेल',
          ),
          payment('e2', nena, 5000, at: day2),
        ],
        currency: Currency.php,
        shopName: 'Nena Sari-sari',
      );

      final restored = Ledger.fromJson(
        jsonDecode(jsonEncode(book.toJson())) as Object?,
      );

      expect(restored.customers, hasLength(2));
      expect(restored.customers.first.name, 'रामू');
      expect(restored.customers.first.phone, '+910000000000');
      expect(restored.entries, hasLength(2));
      expect(restored.entries.first.item, 'तेल, 1 litre');
      expect(restored.entries.first.transcript, 'रामू दो सौ तेल');
      expect(restored.entries.first.at, day1);
      expect(restored.balanceFor('c1'), 20050);
      expect(restored.balanceFor(nena.id), -5000);
      expect(restored.currency, Currency.php);
      expect(restored.shopName, 'Nena Sari-sari');
    });

    test('an empty book round trips', () {
      final restored = Ledger.fromJson(Ledger.empty.toJson());
      expect(restored.customers, isEmpty);
      expect(restored.entries, isEmpty);
      expect(restored.currency, Currency.inr);
      expect(restored.shopName, isNull);
    });

    group('malformed storage opens anyway', () {
      final cases = <(String, Object?)>[
        ('null', null),
        ('a string', 'not a ledger'),
        ('a list', <String>['nope']),
        ('an empty map', <String, Object?>{}),
        ('customers is not a list', <String, Object?>{'customers': 7}),
        (
          'a customer with no id',
          <String, Object?>{
            'customers': <Object?>[
              <String, Object?>{'name': 'Ramu'},
            ],
          },
        ),
        (
          'a customer with a blank name',
          <String, Object?>{
            'customers': <Object?>[
              <String, Object?>{'id': 'c1', 'name': '  '},
            ],
          },
        ),
      ];

      for (final (what, raw) in cases) {
        test('$what gives an empty book', () {
          final ledger = Ledger.fromJson(raw);
          expect(ledger.customers, isEmpty);
          expect(ledger.entries, isEmpty);
          expect(ledger.totalOutstanding(), 0);
        });
      }

      test('unusable entries are dropped, the good ones are kept', () {
        final ledger = Ledger.fromJson(<String, Object?>{
          'currency': 'PHP',
          'customers': <Object?>[
            <String, Object?>{'id': 'c1', 'name': 'Ramu'},
            <String, Object?>{'id': 'c1', 'name': 'Ramu again'}, // duplicate id
          ],
          'entries': <Object?>[
            // Good.
            <String, Object?>{
              'id': 'e1',
              'customerId': 'c1',
              'kind': 'credit',
              'amount': 20000,
              'at': day1.toIso8601String(),
            },
            // Bad in every way that matters.
            <String, Object?>{'id': 'e2'},
            <String, Object?>{
              'id': 'e3',
              'customerId': 'c1',
              'amount': 0,
              'at': day1.toIso8601String(),
            },
            <String, Object?>{
              'id': 'e4',
              'customerId': 'c1',
              'amount': -500,
              'at': day1.toIso8601String(),
            },
            <String, Object?>{
              'id': 'e5',
              'customerId': 'c1',
              'amount': '200',
              'at': day1.toIso8601String(),
            },
            <String, Object?>{
              'id': 'e6',
              'customerId': 'c1',
              'amount': 200,
              'at': 'yesterday',
            },
            // Points at a customer who is not in the book.
            <String, Object?>{
              'id': 'e7',
              'customerId': 'ghost',
              'amount': 200,
              'at': day1.toIso8601String(),
            },
            'not even a map',
          ],
        });

        expect(ledger.customers, hasLength(1));
        expect(ledger.entries.map((e) => e.id).toList(), <String>['e1']);
        expect(ledger.currency, Currency.php);
        expect(ledger.balanceFor('c1'), 20000);
      });

      test('an unknown kind falls back to credit, never to a payment', () {
        final ledger = Ledger.fromJson(<String, Object?>{
          'customers': <Object?>[
            <String, Object?>{'id': 'c1', 'name': 'Ramu'},
          ],
          'entries': <Object?>[
            <String, Object?>{
              'id': 'e1',
              'customerId': 'c1',
              'kind': 'who knows',
              'amount': 20000,
              'at': day1.toIso8601String(),
            },
          ],
        });
        expect(ledger.entries.single.kind, EntryKind.creditGiven);
        expect(ledger.balanceFor('c1'), 20000);
      });

      test('entry kind codes are stable', () {
        expect(EntryKind.creditGiven.code, 'credit');
        expect(EntryKind.paymentReceived.code, 'payment');
        expect(EntryKind.fromCode('credit'), EntryKind.creditGiven);
        expect(EntryKind.fromCode('payment'), EntryKind.paymentReceived);
        expect(EntryKind.fromCode(null), EntryKind.creditGiven);
      });

      test('a blank phone is not stored', () {
        const c = Customer(id: 'c1', name: 'Ramu', phone: '');
        expect(c.toJson().containsKey('phone'), isFalse);
        expect(Customer.fromJson(c.toJson())!.phone, isNull);
      });
    });
  });
}
