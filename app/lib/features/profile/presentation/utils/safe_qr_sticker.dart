import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Builds the printable SafeQR sticker sheet (issues §78.24).
///
/// The point of printing: the in-app card is useless to a first responder when
/// the phone is locked. A sticker on the helmet or bike works with no phone at
/// all. The sheet is A4 with the QR at a fixed physical size ([qrSideMm]) so
/// what comes out of a home printer is scannable and cut-to-size, with the
/// same code repeated [copies] times to cut into several stickers.
///
/// Pure: fonts are passed in, so tests can run without the asset bundle and the
/// caller decides how Bengali glyphs are covered (the PDF default face has none).
Future<Uint8List> buildSafeQrStickerPdf({
  required String payload,
  required String title,
  required String caption,
  required pw.Font baseFont,
  pw.Font? fallbackFont,
  double qrSideMm = 50,
  int copies = 6,
}) async {
  final doc = pw.Document(title: title);
  final theme = pw.ThemeData.withFont(
    base: baseFont,
    bold: baseFont,
    fontFallback: [if (fallbackFont != null) fallbackFont],
  );
  final side = qrSideMm * PdfPageFormat.mm;

  pw.Widget sticker() => pw.Container(
        width: side + 16 * PdfPageFormat.mm,
        padding: const pw.EdgeInsets.all(6 * PdfPageFormat.mm),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(width: 0.6, color: PdfColors.grey700),
          borderRadius: pw.BorderRadius.circular(3 * PdfPageFormat.mm),
        ),
        child: pw.Column(
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            pw.Text(title,
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.red800)),
            pw.SizedBox(height: 3 * PdfPageFormat.mm),
            pw.BarcodeWidget(
              barcode: pw.Barcode.qrCode(errorCorrectLevel: pw.BarcodeQRCorrectionLevel.medium),
              data: payload,
              width: side,
              height: side,
              drawText: false,
            ),
            pw.SizedBox(height: 3 * PdfPageFormat.mm),
            pw.Text(caption,
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey800)),
          ],
        ),
      );

  doc.addPage(pw.Page(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(12 * PdfPageFormat.mm),
    theme: theme,
    build: (_) => pw.Wrap(
      spacing: 6 * PdfPageFormat.mm,
      runSpacing: 6 * PdfPageFormat.mm,
      children: [for (var i = 0; i < copies; i++) sticker()],
    ),
  ));
  return doc.save();
}
