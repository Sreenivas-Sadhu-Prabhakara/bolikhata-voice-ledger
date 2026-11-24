import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/ledger_repository.dart';
import 'data/ledger_store.dart';
import 'data/speech_input.dart';
import 'ui/app_scope.dart';
import 'ui/home_screen.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // If the phone will not give the app its own storage, the book still opens
  // and still adds up — it just cannot be kept. The store reports that and the
  // home screen shows it, rather than the app refusing to start.
  LedgerRepository repository;
  try {
    repository = LedgerRepository(await SharedPreferences.getInstance());
  } on Exception {
    repository = LedgerRepository.unavailable();
  }

  runApp(BoliKhataApp(store: LedgerStore(repository)));
}

class BoliKhataApp extends StatefulWidget {
  const BoliKhataApp({required this.store, super.key});

  final LedgerStore store;

  @override
  State<BoliKhataApp> createState() => _BoliKhataAppState();
}

class _BoliKhataAppState extends State<BoliKhataApp> {
  final SpeechInput _speech = SpeechInput();

  @override
  void dispose() {
    _speech.dispose();
    widget.store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LedgerScope(
      notifier: widget.store,
      child: SpeechScope(
        notifier: _speech,
        child: MaterialApp(
          title: 'BoliKhata',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          home: const HomeScreen(),
        ),
      ),
    );
  }
}
