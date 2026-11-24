import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/entry_draft.dart';
import '../domain/ledger.dart';
import '../domain/money.dart';
import '../domain/utterance_parser.dart';
import 'app_scope.dart';

/// The gate every entry passes through.
///
/// Nothing reaches the book without a person reading it here and tapping save.
/// That is the whole safety story of a voice ledger: the phone may mis-hear,
/// but it may not write.
Future<void> showConfirmEntrySheet(
  BuildContext context,
  EntryDraft draft, {
  required String title,
  String? notice,
  double? confidence,
  VoidCallback? onRetry,
  String? lockedCustomerId,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (sheetContext) => Padding(
    // Lifts the sheet above the keyboard as it opens.
    padding: EdgeInsets.only(
      bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
    ),
    child: _ConfirmEntrySheet(
      draft: draft,
      title: title,
      notice: notice,
      confidence: confidence,
      onRetry: onRetry,
      lockedCustomerId: lockedCustomerId,
    ),
  ),
);

class _ConfirmEntrySheet extends StatefulWidget {
  const _ConfirmEntrySheet({
    required this.draft,
    required this.title,
    this.notice,
    this.confidence,
    this.onRetry,
    this.lockedCustomerId,
  });

  final EntryDraft draft;
  final String title;
  final String? notice;
  final double? confidence;
  final VoidCallback? onRetry;

  /// Set when the sheet was opened from one customer's page, so the entry
  /// cannot wander onto someone else's.
  final String? lockedCustomerId;

  @override
  State<_ConfirmEntrySheet> createState() => _ConfirmEntrySheetState();
}

class _ConfirmEntrySheetState extends State<_ConfirmEntrySheet> {
  late TextEditingController _name;
  late TextEditingController _amount;
  late TextEditingController _item;
  late EntryDraft _draft;
  bool _amountUnreadable = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _draft = widget.draft;
    _name = TextEditingController(text: _draft.name);
    _amount = TextEditingController(
      text: _draft.amount == null ? '' : minorToInputString(_draft.amount!),
    );
    _item = TextEditingController(text: _draft.item);
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _item.dispose();
    super.dispose();
  }

  void _onAmountChanged(String raw) {
    final text = raw.trim();
    final parsed = parseMoneyDigits(text);
    setState(() {
      _amountUnreadable = text.isNotEmpty && parsed == null;
      _draft = parsed == null
          ? _draft.copyWith(clearAmount: true)
          : _draft.copyWith(amount: parsed);
    });
  }

  Future<void> _save() async {
    if (!_draft.isSaveable || _saving) return;
    final store = LedgerScope.read(context);
    // Taken before the sheet closes, because afterwards this context is gone.
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);

    setState(() => _saving = true);
    final entry = await store.saveDraft(_draft);
    navigator.pop();
    if (entry == null) return;

    final ledger = store.ledger;
    final customer = ledger.customerById(entry.customerId);
    final sign = entry.kind == EntryKind.creditGiven ? '' : 'payment ';
    messenger?.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 6),
        content: Text(
          'Saved $sign${formatMoney(entry.amount, ledger.currency)} '
          'for ${customer?.name ?? _draft.name}',
        ),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => store.deleteEntry(entry.id),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final store = LedgerScope.of(context);
    final ledger = store.ledger;
    final problems = _draft.problems();
    final suggestions = _suggestions(ledger);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Nothing is saved until you press Save.',
              style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
            ),
            if (widget.notice != null) ...<Widget>[
              const SizedBox(height: 14),
              _Tinted(
                colour: scheme.secondaryContainer,
                ink: scheme.onSecondaryContainer,
                icon: Icons.info_outline,
                text: widget.notice!,
              ),
            ],
            if (_draft.fromSpeech) ...<Widget>[
              const SizedBox(height: 14),
              _Heard(
                transcript: _draft.transcript,
                confidence: widget.confidence ?? _draft.confidence,
              ),
            ],
            const SizedBox(height: 18),
            if (widget.lockedCustomerId == null) ...<Widget>[
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(fontSize: 20),
                decoration: const InputDecoration(labelText: 'Customer'),
                onChanged: (v) => setState(() {
                  _draft = _draft.copyWith(name: v);
                }),
              ),
              if (suggestions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: suggestions
                        .map(
                          (c) => ActionChip(
                            label: Text(c.name),
                            onPressed: () => setState(() {
                              _name.text = c.name;
                              _draft = _draft.copyWith(name: c.name);
                            }),
                          ),
                        )
                        .toList(),
                  ),
                ),
              const SizedBox(height: 14),
            ],
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                labelText: 'Amount',
                prefixText: '${ledger.currency.symbol} ',
                prefixStyle: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
                errorText: _amountUnreadable
                    ? 'Write it like 200 or 200.50'
                    : problems.contains(DraftProblem.amountTooLarge)
                    ? 'That is too large for one entry'
                    : problems.contains(DraftProblem.amountNotPositive)
                    ? 'An entry needs an amount above zero'
                    : null,
              ),
              onChanged: _onAmountChanged,
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _item,
              style: const TextStyle(fontSize: 18),
              decoration: const InputDecoration(
                labelText: 'What they took (optional)',
              ),
              onChanged: (v) => setState(() {
                _draft = _draft.copyWith(item: v);
              }),
            ),
            const SizedBox(height: 18),
            SegmentedButton<EntryKind>(
              segments: const <ButtonSegment<EntryKind>>[
                ButtonSegment<EntryKind>(
                  value: EntryKind.creditGiven,
                  icon: Icon(Icons.shopping_basket_outlined),
                  label: Text('Credit'),
                ),
                ButtonSegment<EntryKind>(
                  value: EntryKind.paymentReceived,
                  icon: Icon(Icons.payments_outlined),
                  label: Text('Payment'),
                ),
              ],
              selected: <EntryKind>{_draft.kind},
              onSelectionChanged: (s) => setState(() {
                _draft = _draft.copyWith(kind: s.first);
              }),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              icon: const Icon(Icons.check, size: 26),
              label: Text(
                _draft.kind == EntryKind.creditGiven
                    ? 'Save to the book'
                    : 'Save payment',
              ),
              onPressed: _draft.isSaveable && !_saving ? _save : null,
            ),
            if (problems.contains(DraftProblem.nameMissing))
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  'Add the customer before saving.',
                  style: TextStyle(fontSize: 14, color: scheme.error),
                ),
              ),
            const SizedBox(height: 8),
            if (widget.onRetry != null)
              OutlinedButton.icon(
                icon: const Icon(Icons.mic),
                label: const Text('Say it again'),
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onRetry!();
                },
              ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  /// Existing customers whose names start with what has been typed, so a
  /// second page never opens for someone already in the book.
  List<Customer> _suggestions(Ledger ledger) {
    final typed = _name.text.trim().toLowerCase();
    final all = ledger.balances().map((b) => b.customer);
    final matches = typed.isEmpty
        ? all
        : all.where((c) {
            final name = c.name.toLowerCase();
            return name != typed && name.contains(typed);
          });
    return matches.take(4).toList();
  }
}

class _Heard extends StatelessWidget {
  const _Heard({required this.transcript, required this.confidence});

  final String transcript;
  final double confidence;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final band = confidenceBand(confidence);
    final (String label, Color colour, Color ink) = switch (band) {
      ConfidenceBand.high => (
        'Heard clearly',
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
      ),
      ConfidenceBand.medium => (
        'Please check this',
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
      ),
      ConfidenceBand.low => (
        'Not sure — please correct it',
        scheme.errorContainer,
        scheme.onErrorContainer,
      ),
    };

    return _Tinted(
      colour: colour,
      ink: ink,
      icon: Icons.hearing,
      text: '$label\n“$transcript”',
    );
  }
}

class _Tinted extends StatelessWidget {
  const _Tinted({
    required this.colour,
    required this.ink,
    required this.icon,
    required this.text,
  });

  final Color colour;
  final Color ink;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colour,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: ink, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 16, height: 1.35, color: ink),
            ),
          ),
        ],
      ),
    );
  }
}
