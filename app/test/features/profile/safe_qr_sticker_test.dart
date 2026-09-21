import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:throttleiq/features/profile/presentation/utils/safe_qr_sticker.dart';
import 'package:throttleiq/l10n/app_localizations_bn.dart';
import 'package:throttleiq/l10n/app_localizations_en.dart';

/// issues §78.24. A sticker is only useful if it actually renders and scans, so
/// this builds the real PDF (including Bangla text with the bundled font — the
/// PDF default face has no Bengali glyphs, which is the failure to guard).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<pw.Font> bengali() async => pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSansBengali-Variable.ttf'));

  Future<Uint8List> build(dynamic l10n, {int copies = 6}) async => buildSafeQrStickerPdf(
        payload: 'THROTTLEIQ SAFE-QR\nBlood group: O+',
        title: l10n.safeQrStickerTitle as String,
        caption: l10n.safeQrStickerCaption as String,
        baseFont: await bengali(),
        copies: copies,
      );

  test('builds a valid PDF in English', () async {
    final bytes = await build(AppLocalizationsEn());
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(bytes.length, greaterThan(1000));
  });

  test('builds a valid PDF in Bangla using the bundled font', () async {
    final bytes = await build(AppLocalizationsBn());
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    // Bangla embeds the Bengali font, so it is materially larger than English.
    final en = await build(AppLocalizationsEn());
    expect(bytes.length, greaterThan(en.length));
  });

  test('more copies make a bigger sheet, never a broken one', () async {
    final one = await build(AppLocalizationsEn(), copies: 1);
    final six = await build(AppLocalizationsEn(), copies: 6);
    expect(six.length, greaterThan(one.length));
  });

  test('the Bengali font asset the sticker depends on exists', () {
    expect(File('assets/fonts/NotoSansBengali-Variable.ttf').existsSync(), isTrue);
  });
}
