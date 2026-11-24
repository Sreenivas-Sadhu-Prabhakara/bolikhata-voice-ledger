import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/ledger.dart';

/// Reads and writes the whole book to the phone's own storage.
///
/// One JSON document under one key. A shop book is a few hundred lines at
/// most, so there is nothing to gain from a database engine and a lot to gain
/// from a file a person could read with their own eyes.
///
/// There is no server and no sync. Nothing in this class opens a socket.
class LedgerRepository {
  LedgerRepository(SharedPreferences prefs) : _prefs = prefs;

  /// For a phone that would not hand over its storage at all. The app still
  /// runs and still adds up; it just cannot keep anything, and says so.
  LedgerRepository.unavailable() : _prefs = null;

  /// The storage key. Versioned, so a future format change can migrate
  /// instead of guessing.
  static const String storageKey = 'bolikhata.ledger.v1';

  final SharedPreferences? _prefs;

  /// Whether this phone gave the app somewhere to keep the book.
  bool get isPersistent => _prefs != null;

  /// Opens the stored book. A missing, empty or corrupt document comes back as
  /// an empty book rather than an error, because a shopkeeper opening the app
  /// in the middle of a sale cannot act on a parse failure.
  Ledger load() {
    final raw = _prefs?.getString(storageKey);
    if (raw == null || raw.isEmpty) return Ledger.empty;
    try {
      return Ledger.fromJson(jsonDecode(raw) as Object?);
    } on FormatException {
      return Ledger.empty;
    }
  }

  /// Writes the book. Returns false if the platform refused to store it.
  Future<bool> save(Ledger ledger) async {
    final prefs = _prefs;
    if (prefs == null) return false;
    return prefs.setString(storageKey, jsonEncode(ledger.toJson()));
  }

  /// Forgets everything. Used by "delete all data" in settings.
  Future<bool> clear() async => await _prefs?.remove(storageKey) ?? true;
}
