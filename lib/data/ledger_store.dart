import 'package:flutter/foundation.dart';

import '../domain/entry_draft.dart';
import '../domain/ledger.dart';
import '../domain/money.dart';
import 'ledger_repository.dart';

/// Holds the one book the app is showing and writes every change straight to
/// the phone.
///
/// All the arithmetic lives in [Ledger]; this class only decides *when* to
/// save and where new ids come from.
class LedgerStore extends ChangeNotifier {
  LedgerStore(this._repository) : _ledger = _repository.load();

  final LedgerRepository _repository;

  Ledger _ledger;
  Ledger get ledger => _ledger;

  /// Set when the last write could not be stored, so the UI can say so instead
  /// of pretending the entry is safe.
  String? _saveError;
  String? get saveError => _saveError;

  int _sequence = 0;

  /// Ids only have to be unique inside one phone's book, so the clock plus a
  /// counter is enough and keeps the app free of another dependency.
  String _newId(String prefix) {
    _sequence++;
    final stamp = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    return '$prefix-$stamp-$_sequence';
  }

  Future<void> _commit(Ledger next) async {
    _ledger = next;
    notifyListeners();
    final ok = await _repository.save(next);
    final error = ok ? null : 'This phone would not store the last change.';
    if (error != _saveError) {
      _saveError = error;
      notifyListeners();
    }
  }

  /// Finds the customer with this name, or creates one. Matching ignores case
  /// and spacing so "ramu" and "Ramu" stay one page in the book.
  Customer findOrCreateCustomer(String name) {
    final existing = _ledger.customerByName(name);
    if (existing != null) return existing;
    return Customer(id: _newId('c'), name: name.trim());
  }

  /// Writes one draft to the book, creating the customer if they are new.
  ///
  /// Refuses an unsaveable draft outright: this is the only door into the
  /// book, and a draft that has not passed [EntryDraft.isSaveable] never gets
  /// through it.
  Future<LedgerEntry?> saveDraft(EntryDraft draft) async {
    if (!draft.isSaveable) return null;
    final customer = findOrCreateCustomer(draft.name);
    final entry = LedgerEntry(
      id: _newId('e'),
      customerId: customer.id,
      kind: draft.kind,
      amount: draft.amount!,
      at: DateTime.now(),
      item: draft.item.trim(),
      transcript: draft.transcript.trim(),
    );
    await _commit(_ledger.withCustomer(customer).withEntry(entry));
    return entry;
  }

  /// Records a payment against an existing customer.
  Future<LedgerEntry?> recordPayment({
    required String customerId,
    required int amount,
    String note = '',
  }) async {
    if (amount <= 0 || amount > maxAmountMinor) return null;
    if (_ledger.customerById(customerId) == null) return null;
    final entry = LedgerEntry(
      id: _newId('e'),
      customerId: customerId,
      kind: EntryKind.paymentReceived,
      amount: amount,
      at: DateTime.now(),
      item: note.trim(),
    );
    await _commit(_ledger.withEntry(entry));
    return entry;
  }

  Future<void> renameCustomer(String customerId, String name) async {
    final customer = _ledger.customerById(customerId);
    if (customer == null || name.trim().isEmpty) return;
    await _commit(_ledger.withCustomer(customer.copyWith(name: name.trim())));
  }

  Future<void> setCustomerPhone(String customerId, String phone) async {
    final customer = _ledger.customerById(customerId);
    if (customer == null) return;
    await _commit(_ledger.withCustomer(customer.copyWith(phone: phone.trim())));
  }

  Future<void> deleteEntry(String entryId) =>
      _commit(_ledger.withoutEntry(entryId));

  Future<void> deleteCustomer(String customerId) =>
      _commit(_ledger.withoutCustomer(customerId));

  Future<void> setCurrency(Currency currency) =>
      _commit(_ledger.copyWith(currency: currency));

  Future<void> setShopName(String name) =>
      _commit(_ledger.copyWith(shopName: name.trim()));

  /// Empties the book on this phone. There is no copy anywhere else, so the
  /// caller must confirm first.
  Future<void> deleteEverything() async {
    await _repository.clear();
    _ledger = Ledger.empty;
    notifyListeners();
  }
}
