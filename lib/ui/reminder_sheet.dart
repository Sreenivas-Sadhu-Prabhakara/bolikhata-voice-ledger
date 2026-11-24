import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../domain/ledger.dart';
import '../domain/reminder.dart';
import 'app_scope.dart';

/// Writes the reminder and hands it over. **It does not send it.**
///
/// Copy puts the words on the clipboard; Share passes them to the phone's own
/// share sheet. Either way the shopkeeper picks the app, the thread and the
/// moment, and the message goes out under their own name. The app has no
/// messaging permission and no network connection to send it with.
Future<void> showReminderSheet(
  BuildContext context,
  Customer customer,
  int balance,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (_) => _ReminderSheet(customer: customer, balance: balance),
);

class _ReminderSheet extends StatefulWidget {
  const _ReminderSheet({required this.customer, required this.balance});

  final Customer customer;
  final int balance;

  @override
  State<_ReminderSheet> createState() => _ReminderSheetState();
}

class _ReminderSheetState extends State<_ReminderSheet> {
  ReminderLanguage _language = ReminderLanguage.english;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ledger = LedgerScope.of(context).ledger;
    final text = reminderText(
      widget.customer,
      widget.balance,
      _language,
      currency: ledger.currency,
      shopName: ledger.shopName,
    );

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Reminder for ${widget.customer.name}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ReminderLanguage.values
                  .map(
                    (l) => ChoiceChip(
                      label: Text(l.label),
                      selected: _language == l,
                      onSelected: (_) => setState(() => _language = l),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                text,
                style: const TextStyle(fontSize: 18, height: 1.4),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'This app will not send anything. Copy or share it, then send it '
              'yourself from WhatsApp, Messenger or SMS.',
              style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 18),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.copy_all_outlined),
                    label: const Text('Copy'),
                    onPressed: () => _copy(text),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.share_outlined),
                    label: const Text('Share'),
                    onPressed: () => _share(text),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copy(String text) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    await Clipboard.setData(ClipboardData(text: text));
    messenger?.showSnackBar(
      const SnackBar(content: Text('Copied. Paste it in your chat app.')),
    );
  }

  Future<void> _share(String text) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await SharePlus.instance.share(
        ShareParams(text: text, subject: 'Shop account'),
      );
    } on Exception {
      // No share sheet on this phone: the clipboard always works.
      await Clipboard.setData(ClipboardData(text: text));
      messenger?.showSnackBar(
        const SnackBar(
          content: Text(
            'This phone has no share sheet. The message was copied instead.',
          ),
        ),
      );
    }
  }
}
