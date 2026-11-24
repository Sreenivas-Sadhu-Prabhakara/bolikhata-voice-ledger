/// Builds the reminder message a shopkeeper sends to a customer.
///
/// The app writes the words and hands them over. **It never sends anything.**
/// There is no SMS, no messaging API and no network call here — the shopkeeper
/// copies or shares the text and sends it from their own WhatsApp, Messenger
/// or SMS app, under their own name, to the thread they already use.
///
/// Pure Dart: nothing in `lib/domain/` imports Flutter.
library;

import 'ledger.dart';
import 'money.dart';

/// Languages the reminder can be written in.
enum ReminderLanguage {
  english('English'),
  hindi('हिन्दी'),
  tamil('தமிழ்'),
  tagalog('Tagalog'),
  cebuano('Cebuano');

  const ReminderLanguage(this.label);

  /// Name of the language in that language, for the picker.
  final String label;
}

/// Which of the three messages applies.
enum ReminderTone {
  /// The customer owes money.
  owed,

  /// The balance is exactly zero.
  settled,

  /// The customer has paid more than they took.
  advance,
}

/// The only place the sign of a balance is turned into a kind of message.
///
/// A balance of zero or less can never produce [ReminderTone.owed], which is
/// what keeps the app from ever asking a customer for money they do not owe.
ReminderTone reminderToneFor(int balance) {
  if (balance > 0) return ReminderTone.owed;
  if (balance == 0) return ReminderTone.settled;
  return ReminderTone.advance;
}

/// Writes a polite, ready-to-send reminder for [customer].
///
/// [balance] is in minor units, as returned by `Ledger.balanceFor`. The
/// message always names the balance, but the way it names it depends on the
/// sign:
///
/// * positive — the amount is named as pending, with a polite request;
/// * zero — the message says the account is settled and asks for nothing;
/// * negative — the message names the amount as an **advance the shop holds**,
///   and still asks for nothing.
///
/// A negative balance is therefore never rendered as money owed, and the
/// amount is always printed without a minus sign.
String reminderText(
  Customer customer,
  int balance,
  ReminderLanguage language, {
  Currency currency = Currency.inr,
  String? shopName,
}) {
  final tone = reminderToneFor(balance);
  final amount = formatMoneyAbs(balance, currency);
  final name = customer.name.trim();
  final body = switch (language) {
    ReminderLanguage.english => _english(tone, name, amount),
    ReminderLanguage.hindi => _hindi(tone, name, amount),
    ReminderLanguage.tamil => _tamil(tone, name, amount),
    ReminderLanguage.tagalog => _tagalog(tone, name, amount),
    ReminderLanguage.cebuano => _cebuano(tone, name, amount),
  };
  final shop = shopName?.trim();
  if (shop == null || shop.isEmpty) return body;
  return '$body\n— $shop';
}

String _english(ReminderTone tone, String name, String amount) =>
    switch (tone) {
      ReminderTone.owed =>
        'Hello $name, your shop account shows $amount pending. '
            'Please pay whenever it is convenient. Thank you.',
      ReminderTone.settled =>
        'Hello $name, your shop account is fully settled — there is nothing to '
            'pay. Thank you for clearing it.',
      ReminderTone.advance =>
        'Hello $name, there is nothing to pay on your shop account. We are '
            'holding $amount as an advance for your next purchase. Thank you.',
    };

String _hindi(ReminderTone tone, String name, String amount) => switch (tone) {
  ReminderTone.owed =>
    'नमस्ते $name, आपके खाते में $amount बाकी है। '
        'सुविधा हो तो चुका दें। धन्यवाद।',
  ReminderTone.settled =>
    'नमस्ते $name, आपका खाता पूरा चुकता है — कुछ बाकी नहीं है। धन्यवाद।',
  ReminderTone.advance =>
    'नमस्ते $name, कुछ बाकी नहीं है। आपका $amount जमा है, '
        'अगली खरीद में लगा देंगे। धन्यवाद।',
};

String _tamil(ReminderTone tone, String name, String amount) => switch (tone) {
  ReminderTone.owed =>
    'வணக்கம் $name, உங்கள் கணக்கில் $amount பாக்கி உள்ளது. '
        'வசதியான போது செலுத்துங்கள். நன்றி.',
  ReminderTone.settled =>
    'வணக்கம் $name, உங்கள் கணக்கு முழுவதும் தீர்ந்தது — பாக்கி இல்லை. நன்றி.',
  ReminderTone.advance =>
    'வணக்கம் $name, பாக்கி இல்லை. உங்கள் $amount முன்பணமாக உள்ளது. நன்றி.',
};

String _tagalog(
  ReminderTone tone,
  String name,
  String amount,
) => switch (tone) {
  ReminderTone.owed =>
    'Magandang araw $name, $amount pa po ang balanse ninyo sa tindahan. '
        'Pakibayaran po kapag may pagkakataon. Maraming salamat.',
  ReminderTone.settled =>
    'Magandang araw $name, bayad na po lahat — wala na pong balanse. '
        'Maraming salamat sa pagbabayad.',
  ReminderTone.advance =>
    'Magandang araw $name, wala na pong babayaran. May $amount pa pong '
        'sobra na nakahanda para sa susunod ninyong bili. Maraming salamat.',
};

String _cebuano(ReminderTone tone, String name, String amount) =>
    switch (tone) {
      ReminderTone.owed =>
        'Maayong adlaw $name, $amount pa ang balanse ninyo sa tindahan. '
            'Palihog bayri kon makahimo na. Daghang salamat.',
      ReminderTone.settled =>
        'Maayong adlaw $name, bayad na tanan — wala nay balanse. '
            'Daghang salamat sa pagbayad.',
      ReminderTone.advance =>
        'Maayong adlaw $name, wala nay bayranan. Naa pay $amount nga sobra, '
            'andam para sa sunod ninyong palit. Daghang salamat.',
    };
