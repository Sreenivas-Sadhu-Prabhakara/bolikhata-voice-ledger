# BoliKhata — voice-entry credit ledger app for kirana shops and sari-sari stores

A shopkeeper with flour on their hands taps once and says **"Ramu, 200, cooking oil"** in
their own language. The app turns that into a credit-ledger entry — after showing it for
checking. It replaces the paper khata or listahan, and everything stays on the phone.

Explainer site: **[docs/index.html](docs/index.html)** ·
part of [Open MSME](https://sreenivas-sadhu-prabhakara.github.io/openmsme/).

## What it does

- **One-tap voice entry.** Say the customer, the amount and the goods in one sentence.
  The amount can be digits (`200`, `1,200`, `₹200`, `₱200`, `200/-`) or number words
  (`do sau`, `paanch sau`, `ek hazaar`, `irunooru`, `aayiram`, `dalawang daan`,
  `isang libo`, `duha ka gatos`), and it can appear anywhere in the sentence.
- **Always confirmed, never auto-saved.** Speech produces a *draft*. The customer, amount
  and goods each land in an editable field, the app says how confident it is, and the entry
  reaches the book only when the shopkeeper presses save. A wrong amount in a credit book
  is money lost, so the phone may listen but not write. A save can also be undone on the
  spot.
- **A page per customer.** Every credit and every payment, newest first, with a running
  balance. A payment is a separate line, never a rewrite, so the history stays auditable.
- **The numbers that matter first.** Total out on credit on the opening screen, biggest
  debtor at the top of the list.
- **Reminders the shopkeeper sends.** A polite message naming the balance, in five
  languages, ready to copy or share. The app never sends anything itself.
- **Manual export.** CSV of every entry, or a plain-text balance summary.
- **Offline, private, no account.** No sign-up, no server, no analytics, no network calls.

## Who it's for

Kirana shops, sari-sari stores and neighbourhood traders who sell on credit, in India and
the Philippines, and who keep that credit in a paper notebook today — because at the moment
of the sale a notebook beats every app. This one is built for that moment: one hand, a cheap
phone, bright light, no time. Large tap targets, large numbers, no tutorial.

## Languages

Two separate things, worth keeping apart:

**Number words** are understood by this app, from tables in
[`lib/domain/number_words.dart`](lib/domain/number_words.dart):

| Language | Script coverage | Examples |
| --- | --- | --- |
| Hindi | Romanised + Devanagari | `do sau` / `दो सौ` = 200, `paanch sau` / `पाँच सौ` = 500, `ek hazaar` / `एक हज़ार` = 1000 |
| Tamil | Romanised + Tamil script | `irunooru` / `இருநூறு` = 200, `aayiram` / `ஆயிரம்` = 1000 |
| Tagalog | Romanised | `dalawang daan` = 200, `isang libo` = 1000 |
| Cebuano | Romanised | `duha ka gatos` = 200, `usa ka libo` = 1000 |

The tables are deliberately modest: the small numbers, the hundreds and the thousands a shop
entry actually uses. Each language is one named map, so adding a word, a spelling or a
language is a one-line change. **Any other language still works whenever the amount comes
through as digits**, which is what most speech engines produce.

**Reminder messages** can be written in English, Hindi (हिन्दी), Tamil (தமிழ்), Tagalog and
Cebuano — see [`lib/domain/reminder.dart`](lib/domain/reminder.dart).

**Speech recognition itself is not done by this app.** It asks the phone's own speech engine,
so transcription quality depends on that engine, on the language packs installed on the
phone, and on how noisy the shop is.

## Build & run

Flutter 3.44 or newer with Dart 3.12.

```sh
flutter pub get
flutter run                 # on a connected phone or emulator

flutter test                # every ledger and parsing rule
flutter analyze
dart format --output=none --set-exit-if-changed .

flutter build apk --release # Android
flutter build ios --release # iOS, on a Mac with Xcode
```

The app asks for the microphone the first time you record. Refuse it, or run on a phone with
no speech recogniser, and it falls back to typed entry — never a dead end.

## Where the data is stored

One JSON document on the device, under the key `bolikhata.ledger.v1`, written through
`shared_preferences` (Android `SharedPreferences`, iOS `NSUserDefaults`). Nothing else, and
nowhere else.

There is no account, no server and no sync, and the app makes no network calls. The released
Android app requests exactly one permission, the microphone, and no internet permission at
all. Deleting the app deletes the book.

## How the code is laid out

```
lib/
  domain/   pure Dart: every rule, no Flutter imports, unit-tested
  data/     local persistence and the microphone wrapper
  ui/       screens and widgets
test/       table-driven unit tests per domain rule + widget tests of the save gate
docs/       the explainer site published with GitHub Pages
```

`lib/domain/` holds all the business logic and imports no Flutter, no storage and no plugins,
so it runs and is tested without a device — a test enforces this.

| File | What it owns |
| --- | --- |
| `domain/utterance_parser.dart` | Turning one spoken sentence into a draft entry, with a confidence score |
| `domain/number_words.dart` | The four number-word tables |
| `domain/money.dart` | Minor-unit integer amounts, Indian vs western digit grouping, parsing typed and spoken digits |
| `domain/ledger.dart` | Customers, entries, `balanceFor`, `totalOutstanding`, `totalAdvance`, ordering, storage format |
| `domain/entry_draft.dart` | Whether a draft may be saved at all |
| `domain/reminder.dart` | The reminder wording in five languages |
| `domain/export.dart` | CSV and the plain-text summary |
| `domain/dates.dart` | `Today` / `Yesterday` / `10 Jan` labels |

Amounts are integer **minor units** (paise, centavos) everywhere, never floating point, so
adding up a long book cannot drift by a fraction of a paise.

## Dependencies, and why each one is here

Three, plus the Flutter SDK and the lint rules. Each one does something the app cannot do
itself:

| Dependency | Why |
| --- | --- |
| `flutter` | The SDK. |
| `speech_to_text` | The only way to reach the platform speech recogniser — Android's `SpeechRecognizer` and iOS's `SFSpeechRecognizer` — from Dart. The whole product is one tap and one sentence, so this is the app. |
| `shared_preferences` | The smallest well-known local store that works on both platforms. The book is a few hundred lines of JSON; a database engine would be more moving parts for no gain. |
| `share_plus` | Opens the system share sheet so the shopkeeper can pass a reminder or an export to *their own* chat app. The app deliberately has no way to send a message itself. |
| `flutter_lints` | Lint rules, development only. |

The `cupertino_icons` package that comes with a new Flutter project was removed, because
nothing here uses it.

No state-management, date, i18n, HTTP, analytics or crash-reporting package. State is two
small `ChangeNotifier`s behind `InheritedNotifier`; dates and money formatting are a few
tested functions in `lib/domain/`.

## What this does NOT do yet

- **No cloud sync and no backend.** The book lives on one phone. It cannot be opened on a
  second phone, two people cannot keep it at the same time, and there is **no automatic
  backup** — if the phone is lost, wiped or reset, the book goes with it. The manual CSV and
  summary export is the only backup, and you have to remember to take it.
- **No recognition of its own.** The phone's speech engine does the transcribing. Some
  phones need a language pack installed before they transcribe offline, and some vendors'
  engines transcribe on the vendor's servers — a property of the phone, not of this app,
  which has no network access.
- **Number words in four languages only**, and only the modest range listed above. Other
  languages depend on the amount arriving as digits.
- **The parser is rules, not a model.** It will sometimes put the boundary between a name
  and the goods in the wrong place, especially when the amount is spoken first or last.
  That is exactly why nothing is saved without confirmation.
- **No receipts, photos, reminders-on-a-schedule, interest, instalments, item catalogue,
  stock, GST/VAT invoicing or multi-shop accounts.**
- **Not an accounting, tax-filing or credit-scoring tool.** It records what you are owed.
  Balances are only as good as the entries you confirm.
- **English-only interface.** The app understands four languages spoken and writes reminders
  in five, but its own labels are in English.

MIT licensed.
