/// The credit ledger itself: customers, entries and the sums over them.
///
/// This is the paper khata / listahan, modelled directly. A page per customer,
/// a line per transaction, and a balance at the bottom. Nothing is netted off
/// or rewritten: a payment is its own line, so the history stays auditable the
/// way the paper book was.
///
/// Pure Dart: nothing in `lib/domain/` imports Flutter.
library;

import 'money.dart';

/// What a line in the book is.
enum EntryKind {
  /// Goods handed over on credit. Increases what the customer owes.
  creditGiven,

  /// Cash (or transfer) received from the customer. Decreases what they owe.
  paymentReceived;

  /// Stable string used in storage and export files.
  String get code => this == EntryKind.creditGiven ? 'credit' : 'payment';

  /// Reads [code] back, defaulting to [EntryKind.creditGiven].
  static EntryKind fromCode(String? code) =>
      code == 'payment' ? EntryKind.paymentReceived : EntryKind.creditGiven;
}

/// A person who buys on credit.
class Customer {
  const Customer({required this.id, required this.name, this.phone});

  final String id;

  /// As the shopkeeper says it. Not normalised, not transliterated.
  final String name;

  /// Optional, and only ever used to let the shopkeeper pick a chat thread
  /// themselves. The app never dials or messages anyone.
  final String? phone;

  Customer copyWith({String? name, String? phone}) =>
      Customer(id: id, name: name ?? this.name, phone: phone ?? this.phone);

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    if (phone != null && phone!.isNotEmpty) 'phone': phone,
  };

  /// Reads a customer back from storage, or `null` if the record is unusable.
  static Customer? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final name = raw['name'];
    if (id is! String || id.isEmpty) return null;
    if (name is! String || name.trim().isEmpty) return null;
    final phone = raw['phone'];
    return Customer(
      id: id,
      name: name,
      phone: phone is String && phone.isNotEmpty ? phone : null,
    );
  }
}

/// One line in the book.
class LedgerEntry {
  /// Throws [ArgumentError] when [amount] is not positive: a zero-rupee credit
  /// line is a mistake, and a negative one is a payment written the wrong way
  /// round. The sign lives in [kind], never in the amount.
  LedgerEntry({
    required this.id,
    required this.customerId,
    required this.kind,
    required this.amount,
    required this.at,
    this.item = '',
    this.transcript = '',
  }) {
    if (amount <= 0) {
      throw ArgumentError.value(
        amount,
        'amount',
        'must be greater than zero (direction is carried by kind)',
      );
    }
    if (customerId.isEmpty) {
      throw ArgumentError.value(customerId, 'customerId', 'must not be empty');
    }
  }

  final String id;
  final String customerId;
  final EntryKind kind;

  /// Always positive, in minor units (paise / centavos).
  final int amount;

  /// When it happened.
  final DateTime at;

  /// The goods, as spoken or typed. Empty is fine — a khata line often is just
  /// a name and a number.
  final String item;

  /// What the speech engine heard, kept so a wrong entry can be understood
  /// later. Empty when the entry was typed.
  final String transcript;

  /// Credit counts up, payment counts down.
  int get signedAmount => kind == EntryKind.creditGiven ? amount : -amount;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'customerId': customerId,
    'kind': kind.code,
    'amount': amount,
    'at': at.toIso8601String(),
    if (item.isNotEmpty) 'item': item,
    if (transcript.isNotEmpty) 'transcript': transcript,
  };

  /// Reads an entry back from storage, or `null` if the record is unusable.
  /// Corrupt lines are dropped rather than crashing the whole book.
  static LedgerEntry? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final customerId = raw['customerId'];
    final amount = raw['amount'];
    final at = DateTime.tryParse(
      raw['at'] is String ? raw['at'] as String : '',
    );
    if (id is! String || id.isEmpty) return null;
    if (customerId is! String || customerId.isEmpty) return null;
    if (amount is! int || amount <= 0) return null;
    if (at == null) return null;
    final item = raw['item'];
    final transcript = raw['transcript'];
    return LedgerEntry(
      id: id,
      customerId: customerId,
      kind: EntryKind.fromCode(raw['kind'] as String?),
      amount: amount,
      at: at,
      item: item is String ? item : '',
      transcript: transcript is String ? transcript : '',
    );
  }
}

/// A customer with their balance, for the list on the home screen.
class CustomerBalance {
  const CustomerBalance({
    required this.customer,
    required this.balance,
    required this.entryCount,
    this.lastActivity,
  });

  final Customer customer;

  /// Minor units. Positive means they owe the shop; negative means the shop
  /// holds an advance for them.
  final int balance;

  final int entryCount;

  /// Date of the most recent entry, or `null` when there are none.
  final DateTime? lastActivity;

  bool get owes => balance > 0;
  bool get settled => balance == 0;
  bool get inAdvance => balance < 0;
}

/// The whole book. Immutable: every change returns a new [Ledger], which keeps
/// the sums below pure and makes the store a single assignment.
class Ledger {
  const Ledger({
    this.customers = const <Customer>[],
    this.entries = const <LedgerEntry>[],
    this.currency = Currency.inr,
    this.shopName,
  });

  /// An empty book.
  static const Ledger empty = Ledger();

  final List<Customer> customers;
  final List<LedgerEntry> entries;

  /// The shop's own currency. One shop, one currency.
  final Currency currency;

  /// Optional, used to sign reminder messages.
  final String? shopName;

  // ---------------------------------------------------------------- queries

  Customer? customerById(String id) {
    for (final c in customers) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Finds a customer by name, ignoring case and surrounding spaces, so a
  /// second "ramu" does not open a second page in the book.
  Customer? customerByName(String name) {
    final needle = name.trim().toLowerCase();
    if (needle.isEmpty) return null;
    for (final c in customers) {
      if (c.name.trim().toLowerCase() == needle) return c;
    }
    return null;
  }

  /// Every entry for one customer, newest first.
  List<LedgerEntry> entriesFor(String customerId) {
    final mine = entries.where((e) => e.customerId == customerId).toList()
      ..sort((a, b) => b.at.compareTo(a.at));
    return mine;
  }

  /// **The core sum**: everything given on credit, less everything paid back.
  ///
  /// Positive means the customer owes the shop. Zero means settled. Negative
  /// means they have paid more than they took and the shop holds an advance.
  /// A customer with no entries at all is zero.
  int balanceFor(String customerId) {
    var total = 0;
    for (final e in entries) {
      if (e.customerId == customerId) total += e.signedAmount;
    }
    return total;
  }

  /// Money the shop is actually owed: the sum of the **positive** balances
  /// only.
  ///
  /// Advances are deliberately excluded. Netting one customer's advance
  /// against another customer's debt would understate what is out on the
  /// street, which is the one number this app exists to show. Advances are
  /// reported separately by [totalAdvance].
  int totalOutstanding() {
    var total = 0;
    for (final c in customers) {
      final b = balanceFor(c.id);
      if (b > 0) total += b;
    }
    return total;
  }

  /// Money held on account for customers who have overpaid, as a positive
  /// number. Zero when nobody is in advance.
  int totalAdvance() {
    var total = 0;
    for (final c in customers) {
      final b = balanceFor(c.id);
      if (b < 0) total -= b;
    }
    return total;
  }

  /// Every customer with their balance, **biggest debtor first**.
  ///
  /// Equal balances are ordered by name (case-insensitive) so the list never
  /// reshuffles between builds.
  List<CustomerBalance> balances() {
    final out = customers.map((c) {
      final mine = entries.where((e) => e.customerId == c.id).toList();
      DateTime? last;
      for (final e in mine) {
        if (last == null || e.at.isAfter(last)) last = e.at;
      }
      return CustomerBalance(
        customer: c,
        balance: mine.fold<int>(0, (sum, e) => sum + e.signedAmount),
        entryCount: mine.length,
        lastActivity: last,
      );
    }).toList();
    out.sort((a, b) {
      final byBalance = b.balance.compareTo(a.balance);
      if (byBalance != 0) return byBalance;
      return a.customer.name.toLowerCase().compareTo(
        b.customer.name.toLowerCase(),
      );
    });
    return out;
  }

  // --------------------------------------------------------------- mutation

  /// Adds [customer], or replaces the existing record with the same id.
  Ledger withCustomer(Customer customer) {
    final next = customers.where((c) => c.id != customer.id).toList()
      ..add(customer);
    return copyWith(customers: next);
  }

  /// Adds one line to the book.
  Ledger withEntry(LedgerEntry entry) =>
      copyWith(entries: <LedgerEntry>[...entries, entry]);

  /// Removes one line, for fixing a mistake.
  Ledger withoutEntry(String entryId) =>
      copyWith(entries: entries.where((e) => e.id != entryId).toList());

  /// Removes a customer and every line on their page.
  Ledger withoutCustomer(String customerId) => copyWith(
    customers: customers.where((c) => c.id != customerId).toList(),
    entries: entries.where((e) => e.customerId != customerId).toList(),
  );

  Ledger copyWith({
    List<Customer>? customers,
    List<LedgerEntry>? entries,
    Currency? currency,
    String? shopName,
  }) => Ledger(
    customers: customers ?? this.customers,
    entries: entries ?? this.entries,
    currency: currency ?? this.currency,
    shopName: shopName ?? this.shopName,
  );

  // -------------------------------------------------------------- storage

  Map<String, dynamic> toJson() => <String, dynamic>{
    'version': 1,
    'currency': currency.code,
    if (shopName != null && shopName!.isNotEmpty) 'shopName': shopName,
    'customers': customers.map((c) => c.toJson()).toList(),
    'entries': entries.map((e) => e.toJson()).toList(),
  };

  /// Reads a book back from storage. Unusable customer or entry records are
  /// skipped, and entries pointing at a customer that no longer exists are
  /// dropped, so a half-written file still opens.
  static Ledger fromJson(Object? raw) {
    if (raw is! Map) return Ledger.empty;
    final customers = <Customer>[];
    final rawCustomers = raw['customers'];
    if (rawCustomers is List) {
      for (final item in rawCustomers) {
        final c = Customer.fromJson(item);
        if (c != null && customers.every((x) => x.id != c.id)) {
          customers.add(c);
        }
      }
    }
    final ids = customers.map((c) => c.id).toSet();
    final entries = <LedgerEntry>[];
    final rawEntries = raw['entries'];
    if (rawEntries is List) {
      for (final item in rawEntries) {
        final e = LedgerEntry.fromJson(item);
        if (e != null && ids.contains(e.customerId)) entries.add(e);
      }
    }
    final shopName = raw['shopName'];
    return Ledger(
      customers: customers,
      entries: entries,
      currency: Currency.fromCode(raw['currency'] as String?),
      shopName: shopName is String && shopName.isNotEmpty ? shopName : null,
    );
  }
}
