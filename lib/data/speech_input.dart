import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// What the microphone and the phone's speech engine are willing to do.
enum SpeechState {
  /// Not asked yet.
  unknown,

  /// Asking the platform right now.
  preparing,

  /// Ready to listen.
  ready,

  /// Listening.
  listening,

  /// The shopkeeper said no to the microphone, or the system did.
  permissionDenied,

  /// This phone has no usable speech recogniser.
  unavailable,
}

/// Wraps the phone's own speech recogniser.
///
/// Recognition is done by the platform engine — Android's or iOS's — not by
/// this app and not by any server this app talks to. See the README: whether
/// that engine works offline depends on the phone's installed language packs,
/// which is a property of the phone, not of this app.
///
/// Every failure path here ends somewhere usable. If the microphone is
/// refused, or the phone has no recogniser, or recognition fails halfway, the
/// caller is told and the shopkeeper types the entry instead. There is no dead
/// end.
class SpeechInput extends ChangeNotifier {
  SpeechInput({SpeechToText? engine}) : _engine = engine ?? SpeechToText();

  final SpeechToText _engine;

  SpeechState _state = SpeechState.unknown;
  SpeechState get state => _state;

  String _transcript = '';

  /// What the engine has heard so far in this session, partial results
  /// included, so the shopkeeper can watch the words appear.
  String get transcript => _transcript;

  bool _finalResult = false;

  /// True once the engine says it has finished with this utterance.
  bool get hasFinalResult => _finalResult;

  double _level = 0;

  /// Rough loudness, for the pulse on the record button.
  double get level => _level;

  String? _message;

  /// A plain-language explanation of the last failure, or `null`.
  String? get message => _message;

  /// Whether speech can be used at all on this phone.
  bool get canListen =>
      _state == SpeechState.ready || _state == SpeechState.listening;

  bool get isListening => _state == SpeechState.listening;

  /// Asks the platform for the microphone and a recogniser. Safe to call more
  /// than once; the plugin only initialises once.
  Future<bool> prepare() async {
    if (canListen) return true;
    _set(SpeechState.preparing);
    bool ok;
    try {
      ok = await _engine.initialize(onError: _onError, onStatus: _onStatus);
    } on Exception {
      // A platform channel that is not there at all, e.g. an unsupported
      // build. Nothing to recover, so fall back to typing.
      _set(SpeechState.unavailable, message: _unavailableMessage);
      return false;
    }
    if (!ok) {
      final denied = _state == SpeechState.permissionDenied;
      _set(
        denied ? SpeechState.permissionDenied : SpeechState.unavailable,
        message: denied
            ? 'This app cannot hear the microphone. Allow microphone access in '
                  'Settings, or type the entry instead.'
            : 'This phone has no speech recogniser this app can use. '
                  'You can still type every entry.',
      );
      return false;
    }
    _set(SpeechState.ready);
    return true;
  }

  /// Starts listening. [localeId] picks the language pack, e.g. `hi_IN`,
  /// `ta_IN`, `fil_PH` or `en_IN`; `null` uses the phone's own setting.
  Future<bool> start({String? localeId}) async {
    if (!await prepare()) return false;
    _transcript = '';
    _finalResult = false;
    _level = 0;
    try {
      await _engine.listen(
        onResult: _onResult,
        onSoundLevelChange: _onLevel,
        listenOptions: SpeechListenOptions(
          localeId: localeId,
          partialResults: true,
          cancelOnError: true,
          listenMode: ListenMode.dictation,
          // A shop entry is one short sentence. Stop three seconds after the
          // shopkeeper stops talking, and never hold the microphone open for
          // more than half a minute.
          pauseFor: const Duration(seconds: 3),
          listenFor: const Duration(seconds: 30),
        ),
      );
    } on Exception {
      _set(SpeechState.ready, message: _unavailableMessage);
      return false;
    }
    _set(SpeechState.listening);
    return true;
  }

  /// Stops listening but keeps whatever was heard.
  Future<void> stop() async {
    if (_engine.isListening) await _engine.stop();
    if (_state == SpeechState.listening) {
      _set(SpeechState.ready, keepMessage: true);
    }
  }

  /// Stops listening and throws away what was heard.
  Future<void> cancel() async {
    if (_engine.isListening) await _engine.cancel();
    _transcript = '';
    _finalResult = false;
    _level = 0;
    if (_state == SpeechState.listening) {
      _set(SpeechState.ready, keepMessage: true);
    } else {
      notifyListeners();
    }
  }

  /// The language packs this phone actually has, for the language picker.
  /// An empty list means the phone would not say.
  Future<List<LocaleName>> locales() async {
    if (!canListen) return const <LocaleName>[];
    try {
      return await _engine.locales();
    } on Exception {
      return const <LocaleName>[];
    }
  }

  void _onResult(SpeechRecognitionResult result) {
    _transcript = result.recognizedWords;
    _finalResult = result.finalResult;
    notifyListeners();
  }

  void _onLevel(double level) {
    _level = level;
    notifyListeners();
  }

  void _onStatus(String status) {
    if (status == SpeechToText.listeningStatus) {
      _set(SpeechState.listening);
    } else if (_state == SpeechState.listening) {
      _set(SpeechState.ready, keepMessage: true);
    }
  }

  void _onError(SpeechRecognitionError error) {
    final msg = error.errorMsg.toLowerCase();
    if (msg.contains('permission')) {
      _set(
        SpeechState.permissionDenied,
        message:
            'The microphone is blocked. Allow it in Settings, or type the '
            'entry instead.',
      );
      return;
    }
    if (msg.contains('no match') || msg.contains('speech_timeout')) {
      _set(
        SpeechState.ready,
        message: 'Nothing was heard. Try again, or type the entry.',
      );
      return;
    }
    // The platform codes (`error_network`, `error_busy`, `error_audio`, …)
    // turned into something a shopkeeper can act on. The network one matters:
    // it means the *phone's* recogniser wanted a connection, not this app.
    final String plain;
    if (msg.contains('network')) {
      plain =
          'This phone’s speech engine wanted an internet connection and '
          'could not get one. Install an offline language pack in the phone '
          'settings, or type the entry.';
    } else if (msg.contains('busy')) {
      plain =
          'The microphone is busy. End any call or recording, then try again.';
    } else if (msg.contains('audio')) {
      plain = 'The microphone could not be read. Try again, or type the entry.';
    } else {
      plain = 'Speech did not work this time. Try again, or type the entry.';
    }
    _set(
      error.permanent ? SpeechState.unavailable : SpeechState.ready,
      message: plain,
    );
  }

  /// Kept free of the platform's own wording: a shopkeeper mid-sale needs to
  /// know what to do next, not what the exception was called.
  static const String _unavailableMessage =
      'Speech is not working on this phone right now. '
      'You can still type every entry.';

  /// Moves to [state] and, unless [keepMessage] is set, replaces the
  /// explanation — so a successful step clears the last failure.
  void _set(SpeechState state, {String? message, bool keepMessage = false}) {
    _state = state;
    if (!keepMessage) _message = message;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_engine.isListening) _engine.cancel();
    super.dispose();
  }
}
