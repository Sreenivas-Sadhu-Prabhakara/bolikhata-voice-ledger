import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../domain/export.dart';
import '../domain/money.dart';
import 'app_scope.dart';

/// The shop's own settings, the manual backup, and a plain statement of what
/// this app does not do.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  TextEditingController? _shopName;

  @override
  void dispose() {
    _shopName?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = LedgerScope.of(context);
    final ledger = store.ledger;
    final scheme = Theme.of(context).colorScheme;
    _shopName ??= TextEditingController(text: ledger.shopName ?? '');

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: <Widget>[
          _Heading('Your shop'),
          TextField(
            controller: _shopName,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Shop name (used to sign reminders)',
            ),
            onChanged: store.setShopName,
          ),
          const SizedBox(height: 16),
          Text(
            'Currency',
            style: TextStyle(fontSize: 15, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          SegmentedButton<Currency>(
            segments: const <ButtonSegment<Currency>>[
              ButtonSegment<Currency>(
                value: Currency.inr,
                label: Text('₹ Rupees'),
              ),
              ButtonSegment<Currency>(
                value: Currency.php,
                label: Text('₱ Pesos'),
              ),
            ],
            selected: <Currency>{ledger.currency},
            onSelectionChanged: (s) => store.setCurrency(s.first),
          ),
          const SizedBox(height: 28),

          _Heading('Backup'),
          Text(
            'There is no cloud backup and no sync. The book lives on this '
            'phone only, so if the phone is lost or wiped, the book goes with '
            'it. Export it now and then and keep the file somewhere safe.',
            style: TextStyle(fontSize: 16, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            icon: const Icon(Icons.table_view_outlined),
            label: const Text('Export every entry (CSV)'),
            onPressed: () => _share(
              exportCsv(ledger),
              'Credit book export',
              'The export was copied to the clipboard instead.',
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            icon: const Icon(Icons.summarize_outlined),
            label: const Text('Share a balance summary'),
            onPressed: () => _share(
              exportSummary(ledger),
              'Credit book summary',
              'The summary was copied to the clipboard instead.',
            ),
          ),
          const SizedBox(height: 28),

          _Heading('What this app does'),
          const _Bullets(<String>[
            'Records a credit entry from one spoken sentence, in your own '
                'language, and always shows it for checking before saving.',
            'Keeps a page per customer, with every credit and payment, and a '
                'running balance.',
            'Writes a polite reminder message you can copy or share.',
          ]),
          const SizedBox(height: 20),

          _Heading('What this app does not do'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.secondaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: DefaultTextStyle(
              style: TextStyle(
                fontSize: 16,
                height: 1.4,
                color: scheme.onSecondaryContainer,
              ),
              child: const _Bullets(<String>[
                'No account, no cloud, no sync. Nothing leaves this phone, so '
                    'the book cannot be opened on a second phone and there is '
                    'no automatic backup.',
                'It never sends a message or an SMS. You send reminders '
                    'yourself from your own chat app.',
                'It does not recognise speech by itself — your phone’s '
                    'own speech engine does that, and how well it works '
                    'depends on the phone and its installed languages.',
                'Number words are understood in Hindi, Tamil, Tagalog and '
                    'Cebuano, plus digits in any language. Other languages '
                    'still work if the amount comes through as digits.',
                'It is a record of what you are owed, not an accounting or tax '
                    'filing tool, and it charges no interest.',
              ]),
            ),
          ),
          const SizedBox(height: 28),

          _Heading('Danger'),
          OutlinedButton.icon(
            icon: Icon(Icons.delete_forever_outlined, color: scheme.error),
            label: Text(
              'Delete the whole book',
              style: TextStyle(color: scheme.error),
            ),
            onPressed: _confirmWipe,
          ),
          const SizedBox(height: 10),
          Text(
            'Because nothing is stored anywhere else, this cannot be undone.',
            style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Future<void> _share(String text, String subject, String fallback) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await SharePlus.instance.share(ShareParams(text: text, subject: subject));
    } on Exception {
      await Clipboard.setData(ClipboardData(text: text));
      messenger?.showSnackBar(SnackBar(content: Text(fallback)));
    }
  }

  Future<void> _confirmWipe() async {
    final store = LedgerScope.read(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete everything?'),
        content: const Text(
          'Every customer and every entry on this phone will be erased. '
          'There is no copy anywhere else.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep my book'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete everything'),
          ),
        ],
      ),
    );
    if (ok ?? false) {
      await store.deleteEverything();
      _shopName?.text = '';
    }
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(text, style: Theme.of(context).textTheme.titleLarge),
  );
}

class _Bullets extends StatelessWidget {
  const _Bullets(this.lines);

  final List<String> lines;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: lines
        .map(
          (line) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text('•  '),
                Expanded(child: Text(line)),
              ],
            ),
          ),
        )
        .toList(),
  );
}
