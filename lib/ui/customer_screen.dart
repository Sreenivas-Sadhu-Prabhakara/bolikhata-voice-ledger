import 'package:flutter/material.dart';

import '../domain/dates.dart';
import '../domain/entry_draft.dart';
import '../domain/ledger.dart';
import '../domain/money.dart';
import 'app_scope.dart';
import 'confirm_entry_sheet.dart';
import 'reminder_sheet.dart';
import 'theme.dart';

/// One customer's page in the book: where they stand, and every line behind
/// that number.
class CustomerScreen extends StatelessWidget {
  const CustomerScreen({required this.customerId, super.key});

  final String customerId;

  @override
  Widget build(BuildContext context) {
    final store = LedgerScope.of(context);
    final ledger = store.ledger;
    final customer = ledger.customerById(customerId);

    if (customer == null) {
      // Deleted from under us; go back rather than show an empty page.
      return Scaffold(
        appBar: AppBar(),
        body: const Center(
          child: Text('This customer is no longer in the book.'),
        ),
      );
    }

    final balance = ledger.balanceFor(customerId);
    final entries = ledger.entriesFor(customerId);
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: Text(customer.name),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Rename or remove',
            onPressed: () => _editCustomer(context, customer),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _BalanceHeader(balance: balance, currency: ledger.currency),
            Expanded(
              child: entries.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'No entries on this page yet.',
                          style: TextStyle(
                            fontSize: 17,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: entries.length,
                      separatorBuilder: (_, _) =>
                          Divider(color: scheme.outlineVariant),
                      itemBuilder: (context, i) => _EntryRow(
                        entry: entries[i],
                        currency: ledger.currency,
                        now: now,
                        onDelete: () =>
                            _confirmDelete(context, entries[i], ledger),
                      ),
                    ),
            ),
            _Actions(customer: customer, balance: balance),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    LedgerEntry entry,
    Ledger ledger,
  ) async {
    final store = LedgerScope.read(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove this line?'),
        content: Text(
          '${formatMoney(entry.amount, ledger.currency)}'
          '${entry.item.isEmpty ? '' : ' · ${entry.item}'}\n\n'
          'The balance will change. This cannot be undone.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok ?? false) await store.deleteEntry(entry.id);
  }

  Future<void> _editCustomer(BuildContext context, Customer customer) async {
    final store = LedgerScope.read(context);
    final navigator = Navigator.of(context);
    final controller = TextEditingController(text: customer.name);
    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Customer'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop('delete'),
            child: const Text('Remove customer'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop('rename'),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (action == 'rename') {
      await store.renameCustomer(customer.id, controller.text);
    } else if (action == 'delete') {
      await store.deleteCustomer(customer.id);
      navigator.pop();
    }
    controller.dispose();
  }
}

class _BalanceHeader extends StatelessWidget {
  const _BalanceHeader({required this.balance, required this.currency});

  final int balance;
  final Currency currency;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = balance > 0
        ? 'Pending'
        : balance == 0
        ? 'Settled'
        : 'In advance';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: TextStyle(fontSize: 15, color: scheme.onSurfaceVariant),
          ),
          Text(
            formatMoneyAbs(balance, currency),
            style: TextStyle(
              fontSize: 38,
              fontWeight: FontWeight.w800,
              height: 1.15,
              color: AppTheme.balanceInk(balance, scheme),
            ),
          ),
        ],
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({
    required this.entry,
    required this.currency,
    required this.now,
    required this.onDelete,
  });

  final LedgerEntry entry;
  final Currency currency;
  final DateTime now;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final credit = entry.kind == EntryKind.creditGiven;
    final subtitle = <String>[
      formatDayLabel(entry.at, now: now),
      formatTime(entry.at),
      if (entry.item.isNotEmpty) entry.item,
    ].join(' · ');

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Icon(
        credit ? Icons.north_east : Icons.south_west,
        color: credit
            ? AppTheme.balanceInk(1, scheme)
            : AppTheme.balanceInk(-1, scheme),
        size: 28,
      ),
      title: Text(
        '${credit ? '' : '−'}${formatMoney(entry.amount, currency)}',
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            subtitle,
            style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
          ),
          // What the phone heard, kept with the line so a wrong entry can be
          // understood later instead of just argued about.
          if (entry.transcript.isNotEmpty)
            Text(
              '“${entry.transcript}”',
              style: TextStyle(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: scheme.outline,
              ),
            ),
        ],
      ),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        tooltip: 'Remove this line',
        onPressed: onDelete,
      ),
      isThreeLine: entry.transcript.isNotEmpty,
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.customer, required this.balance});

  final Customer customer;
  final int balance;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: FilledButton.icon(
              icon: const Icon(Icons.payments_outlined),
              label: const Text('Payment'),
              onPressed: () => showConfirmEntrySheet(
                context,
                EntryDraft(
                  name: customer.name,
                  kind: EntryKind.paymentReceived,
                ),
                title: 'Payment from ${customer.name}',
                lockedCustomerId: customer.id,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.chat_outlined),
              label: const Text('Reminder'),
              onPressed: () => showReminderSheet(context, customer, balance),
            ),
          ),
        ],
      ),
    );
  }
}
