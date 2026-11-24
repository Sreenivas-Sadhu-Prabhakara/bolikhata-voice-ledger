import 'package:flutter/material.dart';

import '../domain/dates.dart';
import '../domain/entry_draft.dart';
import '../domain/ledger.dart';
import '../domain/money.dart';
import 'app_scope.dart';
import 'confirm_entry_sheet.dart';
import 'customer_screen.dart';
import 'record_sheet.dart';
import 'settings_screen.dart';
import 'theme.dart';

/// The book, open at the summary page: what is out on credit, and who has it.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = LedgerScope.of(context);
    final ledger = store.ledger;
    final rows = ledger.balances();

    return Scaffold(
      appBar: AppBar(
        title: const Text('BoliKhata'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            iconSize: 28,
            tooltip: 'Settings and export',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            if (store.saveError != null) _SaveErrorBanner(store.saveError!),
            _Totals(ledger: ledger, rows: rows),
            Expanded(
              child: rows.isEmpty
                  ? const _EmptyBook()
                  : _CustomerList(ledger: ledger, rows: rows),
            ),
            const _RecordBar(),
          ],
        ),
      ),
    );
  }
}

class _SaveErrorBanner extends StatelessWidget {
  const _SaveErrorBanner(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: scheme.errorContainer,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: <Widget>[
          Icon(Icons.warning_amber_rounded, color: scheme.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$message Write it on paper for now.',
              style: TextStyle(color: scheme.onErrorContainer, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}

class _Totals extends StatelessWidget {
  const _Totals({required this.ledger, required this.rows});

  final Ledger ledger;

  /// Passed in already computed, so opening the app walks the book once
  /// rather than once per number on the screen.
  final List<CustomerBalance> rows;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final outstanding = ledger.totalOutstanding();
    final advance = ledger.totalAdvance();
    final owing = rows.where((b) => b.owes).length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Out on credit',
            style: TextStyle(fontSize: 15, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 2),
          Text(
            formatMoney(outstanding, ledger.currency),
            style: TextStyle(
              fontSize: 38,
              fontWeight: FontWeight.w800,
              height: 1.1,
              color: AppTheme.balanceInk(outstanding, scheme),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            owing == 0
                ? 'Nobody owes anything right now'
                : owing == 1
                ? '1 customer owes you'
                : '$owing customers owe you',
            style: TextStyle(fontSize: 15, color: scheme.onSurfaceVariant),
          ),
          if (advance > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Advances held: ${formatMoney(advance, ledger.currency)}',
                style: TextStyle(fontSize: 15, color: scheme.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }
}

class _CustomerList extends StatelessWidget {
  const _CustomerList({required this.ledger, required this.rows});

  final Ledger ledger;
  final List<CustomerBalance> rows;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 8),
      itemCount: rows.length,
      separatorBuilder: (_, _) => Divider(color: scheme.outlineVariant),
      itemBuilder: (context, index) {
        final row = rows[index];
        final label = row.lastActivity == null
            ? 'No entries yet'
            : '${row.entryCount} ${row.entryCount == 1 ? 'entry' : 'entries'}'
                  ' · ${formatDayLabel(row.lastActivity!, now: now)}';

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 6,
          ),
          title: Text(
            row.customer.name,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            label,
            style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                formatMoneyAbs(row.balance, ledger.currency),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.balanceInk(row.balance, scheme),
                ),
              ),
              Text(
                row.owes
                    ? 'pending'
                    : row.settled
                    ? 'settled'
                    : 'in advance',
                style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => CustomerScreen(customerId: row.customer.id),
            ),
          ),
        );
      },
    );
  }
}

class _EmptyBook extends StatelessWidget {
  const _EmptyBook();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(Icons.menu_book_outlined, size: 64, color: scheme.outline),
            const SizedBox(height: 18),
            Text(
              'The book is empty',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Press the big button and say the name, the amount and what they '
              'took — "Ramu, 200, cooking oil" — in your own '
              'language. You will see it on screen before anything is saved.',
              style: TextStyle(fontSize: 16, color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordBar extends StatelessWidget {
  const _RecordBar();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Column(
        children: <Widget>[
          SizedBox(
            height: AppTheme.recordButtonHeight,
            child: FilledButton.icon(
              icon: const Icon(Icons.mic, size: 34),
              label: const Text(
                'Record an entry',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              onPressed: () => startRecordFlow(context),
            ),
          ),
          const SizedBox(height: 4),
          TextButton.icon(
            icon: const Icon(Icons.keyboard_outlined),
            label: const Text('Type an entry instead'),
            onPressed: () => showConfirmEntrySheet(
              context,
              const EntryDraft(),
              title: 'New entry',
            ),
          ),
        ],
      ),
    );
  }
}
