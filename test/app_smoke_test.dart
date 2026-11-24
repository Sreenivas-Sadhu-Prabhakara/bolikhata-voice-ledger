import 'package:bolikhata/data/ledger_repository.dart';
import 'package:bolikhata/data/ledger_store.dart';
import 'package:bolikhata/domain/ledger.dart';
import 'package:bolikhata/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// These run the real widget tree over a book held in memory, so they cover
/// the one rule that cannot be unit-tested: a spoken or typed entry reaches
/// the book only after a person presses Save.
///
/// `LedgerRepository.unavailable()` keeps the test off the storage plugin; the
/// store, the screens and the arithmetic are the real ones.
Future<LedgerStore> pumpApp(WidgetTester tester) async {
  // A small, cheap phone held in one hand.
  tester.view.physicalSize = const Size(420, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final store = LedgerStore(LedgerRepository.unavailable());
  await tester.pumpWidget(BoliKhataApp(store: store));
  await tester.pumpAndSettle();
  return store;
}

/// Types one entry through the real confirmation sheet and saves it, then
/// clears the "Undo" snackbar, which on a real phone fades after six seconds
/// but under the test binding sits there covering the buttons underneath.
Future<void> saveTypedEntry(
  WidgetTester tester, {
  required String name,
  required String amount,
  String? item,
}) async {
  await tester.tap(find.text('Type an entry instead'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField).at(0), name);
  await tester.enterText(find.byType(TextField).at(1), amount);
  if (item != null) {
    await tester.enterText(find.byType(TextField).at(2), item);
  }
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton, 'Save to the book'));
  await tester.pumpAndSettle();

  expect(find.text('Undo'), findsOneWidget, reason: 'a save is undoable');
  tester
      .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
      .removeCurrentSnackBar();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('an empty book invites the first entry', (tester) async {
    await pumpApp(tester);

    expect(find.text('BoliKhata'), findsOneWidget);
    expect(find.text('The book is empty'), findsOneWidget);
    expect(find.text('Record an entry'), findsOneWidget);
    expect(find.text('Type an entry instead'), findsOneWidget);
    expect(find.text('Out on credit'), findsOneWidget);
    expect(find.text('₹0'), findsOneWidget);
    expect(find.text('Nobody owes anything right now'), findsOneWidget);
  });

  testWidgets('nothing is saved until Save is pressed', (tester) async {
    final store = await pumpApp(tester);

    await tester.tap(find.text('Type an entry instead'));
    await tester.pumpAndSettle();

    // The confirmation sheet is the gate, and it says so.
    expect(find.text('New entry'), findsOneWidget);
    expect(find.text('Nothing is saved until you press Save.'), findsOneWidget);

    // With nothing filled in, Save cannot be pressed.
    final save = find.widgetWithText(FilledButton, 'Save to the book');
    expect(save, findsOneWidget);
    expect(tester.widget<FilledButton>(save).onPressed, isNull);
    expect(find.text('Add the customer before saving.'), findsOneWidget);

    // A name alone is not enough either.
    await tester.enterText(find.byType(TextField).at(0), 'Ramu');
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(save).onPressed, isNull);

    // Name and amount: now it can be saved, and only now.
    await tester.enterText(find.byType(TextField).at(1), '200');
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
    expect(store.ledger.entries, isEmpty);

    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    // One entry, one customer, 200 rupees, on the home screen.
    expect(store.ledger.entries, hasLength(1));
    expect(store.ledger.customers.single.name, 'Ramu');
    expect(store.ledger.totalOutstanding(), 20000);
    expect(store.ledger.entries.single.kind, EntryKind.creditGiven);
    expect(find.text('Ramu'), findsOneWidget);
    expect(find.text('₹200'), findsWidgets);
  });

  testWidgets('a bad amount is rejected with an explanation', (tester) async {
    final store = await pumpApp(tester);

    await tester.tap(find.text('Type an entry instead'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Ramu');
    await tester.enterText(find.byType(TextField).at(1), '2.0.0');
    await tester.pumpAndSettle();

    expect(find.text('Write it like 200 or 200.50'), findsOneWidget);
    final save = find.widgetWithText(FilledButton, 'Save to the book');
    expect(tester.widget<FilledButton>(save).onPressed, isNull);
    expect(store.ledger.entries, isEmpty);
  });

  testWidgets('the customer page shows the balance and its lines', (
    tester,
  ) async {
    final store = await pumpApp(tester);

    await saveTypedEntry(tester, name: 'Nena', amount: '500', item: 'rice');

    expect(store.ledger.totalOutstanding(), 50000);

    await tester.tap(find.text('Nena'));
    await tester.pumpAndSettle();

    expect(find.text('Pending'), findsOneWidget);
    expect(find.text('₹500'), findsWidgets);
    expect(find.textContaining('rice'), findsOneWidget);
    expect(find.text('Payment'), findsOneWidget);
    expect(find.text('Reminder'), findsOneWidget);
  });

  testWidgets('a reminder can be written but never sent by the app', (
    tester,
  ) async {
    await pumpApp(tester);
    await saveTypedEntry(tester, name: 'Ramu', amount: '200');

    await tester.tap(find.text('Ramu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reminder'));
    await tester.pumpAndSettle();

    expect(find.text('Reminder for Ramu'), findsOneWidget);
    expect(find.textContaining('₹200 pending'), findsOneWidget);
    expect(
      find.textContaining('This app will not send anything'),
      findsOneWidget,
    );
    expect(find.widgetWithText(OutlinedButton, 'Copy'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Share'), findsOneWidget);

    // Switching language rewrites the same balance in another language.
    await tester.tap(find.text('हिन्दी'));
    await tester.pumpAndSettle();
    expect(find.textContaining('नमस्ते Ramu'), findsOneWidget);
  });

  testWidgets('settings state what the app will not do', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('There is no cloud backup and no sync'),
      findsOneWidget,
    );
    expect(find.text('Export every entry (CSV)'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('What this app does not do'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('What this app does not do'), findsOneWidget);
    expect(
      find.textContaining('No account, no cloud, no sync'),
      findsOneWidget,
    );
    expect(
      find.textContaining('your phone’s own speech engine'),
      findsOneWidget,
    );
  });
}
