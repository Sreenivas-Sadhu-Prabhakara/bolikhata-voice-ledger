import 'package:flutter/material.dart';

import '../data/speech_input.dart';
import '../domain/entry_draft.dart';
import '../domain/utterance_parser.dart';
import 'app_scope.dart';
import 'confirm_entry_sheet.dart';
import 'theme.dart';

/// One tap, one sentence, one entry.
///
/// Asks for the microphone, listens, and hands whatever was heard to the
/// confirmation sheet. Every failure lands on the same confirmation sheet with
/// an empty draft, so a refused microphone or a silent recogniser costs the
/// shopkeeper a few taps, not the entry.
Future<void> startRecordFlow(BuildContext context) async {
  final speech = SpeechScope.read(context);
  final ready = await speech.prepare();
  if (!context.mounted) return;

  if (!ready) {
    final reason = speech.message ?? 'Speech is not available on this phone.';
    await showConfirmEntrySheet(
      context,
      const EntryDraft(),
      title: 'Type the entry',
      notice: reason,
    );
    return;
  }

  final transcript = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    builder: (_) => const _RecordSheet(),
  );
  if (!context.mounted) return;
  if (transcript == null) return; // cancelled

  final parsed = parseUtterance(transcript);
  final heardNothing = transcript.trim().isEmpty;
  await showConfirmEntrySheet(
    context,
    EntryDraft.fromParsed(parsed),
    title: heardNothing ? 'Type the entry' : 'Check this entry',
    notice: heardNothing
        ? 'Nothing was heard, so nothing was filled in.'
        : null,
    confidence: parsed.confidence,
    onRetry: () => startRecordFlow(context),
  );
}

class _RecordSheet extends StatefulWidget {
  const _RecordSheet();

  @override
  State<_RecordSheet> createState() => _RecordSheetState();
}

class _RecordSheetState extends State<_RecordSheet> {
  SpeechInput? _speech;
  bool _finishing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_speech != null) return;
    final speech = SpeechScope.read(context);
    _speech = speech;
    speech.addListener(_onSpeechChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => speech.start());
  }

  @override
  void dispose() {
    _speech?.removeListener(_onSpeechChanged);
    // Dismissed with the back button: let go of the microphone.
    if (!_finishing) _speech?.cancel();
    super.dispose();
  }

  void _onSpeechChanged() {
    final speech = _speech;
    if (speech == null || _finishing || !mounted) return;
    // The engine says the sentence is finished, or it stopped on its own after
    // the pause. Either way, take what it heard to the confirmation sheet.
    final stopped =
        speech.hasFinalResult ||
        (speech.state != SpeechState.listening &&
            speech.state != SpeechState.preparing &&
            speech.transcript.isNotEmpty);
    if (stopped) _finish(speech.transcript);
  }

  Future<void> _finish(String transcript) async {
    if (_finishing) return;
    _finishing = true;
    final speech = _speech;
    if (speech != null) await speech.stop();
    if (!mounted) return;
    Navigator.of(context).pop(transcript);
  }

  Future<void> _cancel() async {
    _finishing = true;
    await _speech?.cancel();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final speech = _speech;
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: AnimatedBuilder(
          animation: speech ?? const AlwaysStoppedAnimation<double>(0),
          builder: (context, _) {
            final listening = speech?.isListening ?? false;
            final transcript = speech?.transcript ?? '';
            final level = speech?.level ?? 0;

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Center(
                  child: Text(
                    listening ? 'Listening…' : 'Getting ready…',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    'Say the name, the amount and the goods',
                    style: TextStyle(
                      fontSize: 15,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Center(
                  child: _Pulse(level: level, active: listening),
                ),
                const SizedBox(height: 22),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 96),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      transcript.isEmpty ? 'Nothing heard yet…' : transcript,
                      style: TextStyle(
                        fontSize: transcript.isEmpty ? 16 : 24,
                        height: 1.3,
                        fontWeight: transcript.isEmpty
                            ? FontWeight.w400
                            : FontWeight.w600,
                        color: transcript.isEmpty
                            ? scheme.onSurfaceVariant
                            : scheme.onSurface,
                      ),
                    ),
                  ),
                ),
                if (speech?.message != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      speech!.message!,
                      style: TextStyle(fontSize: 15, color: scheme.error),
                    ),
                  ),
                const SizedBox(height: 18),
                if (!listening && transcript.isEmpty)
                  SizedBox(
                    height: AppTheme.tapTarget + 8,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.replay, size: 28),
                      label: const Text('Listen again'),
                      onPressed: () => speech?.start(),
                    ),
                  )
                else
                  SizedBox(
                    height: AppTheme.tapTarget + 8,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.check, size: 28),
                      label: const Text('Done'),
                      onPressed: () => _finish(transcript),
                    ),
                  ),
                const SizedBox(height: 8),
                if (!listening && transcript.isEmpty)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.keyboard_outlined),
                    label: const Text('Type it instead'),
                    onPressed: () => _finish(''),
                  )
                else
                  OutlinedButton(
                    onPressed: _cancel,
                    child: const Text('Cancel'),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// A circle that grows with the loudness, so a shopkeeper can see the phone is
/// hearing them without reading anything.
class _Pulse extends StatelessWidget {
  const _Pulse({required this.level, required this.active});

  final double level;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // The plugin reports roughly -2..10 on Android and 0..10 on iOS.
    final normalised = ((level + 2) / 12).clamp(0.0, 1.0);
    final size = 96.0 + (active ? normalised * 48.0 : 0.0);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active
            ? scheme.primary.withValues(alpha: 0.18)
            : scheme.surfaceContainerHighest,
      ),
      child: Icon(
        active ? Icons.mic : Icons.mic_none,
        size: 48,
        color: active ? scheme.primary : scheme.onSurfaceVariant,
      ),
    );
  }
}
