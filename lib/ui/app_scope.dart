import 'package:flutter/widgets.dart';

import '../data/ledger_store.dart';
import '../data/speech_input.dart';

/// Hands the book and the microphone down the widget tree and rebuilds the
/// screens above them when either changes.
///
/// Two small [InheritedNotifier]s instead of a state-management package: the
/// app has exactly two pieces of shared state, and a dependency that has to be
/// justified in the README should buy more than this.
class LedgerScope extends InheritedNotifier<LedgerStore> {
  const LedgerScope({
    required LedgerStore super.notifier,
    required super.child,
    super.key,
  });

  static LedgerStore of(BuildContext context) {
    final store = context
        .dependOnInheritedWidgetOfExactType<LedgerScope>()
        ?.notifier;
    assert(store != null, 'No LedgerScope above this widget');
    return store!;
  }

  /// For callbacks that only need to act, not rebuild.
  static LedgerStore read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<LedgerScope>();
    assert(scope?.notifier != null, 'No LedgerScope above this widget');
    return scope!.notifier!;
  }
}

class SpeechScope extends InheritedNotifier<SpeechInput> {
  const SpeechScope({
    required SpeechInput super.notifier,
    required super.child,
    super.key,
  });

  static SpeechInput of(BuildContext context) {
    final speech = context
        .dependOnInheritedWidgetOfExactType<SpeechScope>()
        ?.notifier;
    assert(speech != null, 'No SpeechScope above this widget');
    return speech!;
  }

  static SpeechInput read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<SpeechScope>();
    assert(scope?.notifier != null, 'No SpeechScope above this widget');
    return scope!.notifier!;
  }
}
