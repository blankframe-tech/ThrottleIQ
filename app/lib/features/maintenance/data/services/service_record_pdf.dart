import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../core/utils/bike_image_resolver.dart';
import '../../../../core/utils/error_reporter.dart';
import '../../domain/entities/service_visit.dart';

/// The words the PDF needs, resolved by the caller in the app language —
/// keeps this file free of Flutter and l10n so it builds in a plain test.
class ServiceRecordStrings {
  final String title;
  final String bikeLine;
  final String generatedOn;
  final String colDate;
  final String colOdometer;
  final String colWork;
  final String colShop;
  final String colCost;
  final String totalLine;
  final String footer;
  final String Function(DateTime) formatDate;
  final String Function(double km) formatKm;
  final String Function(ServiceVisit) workOf;
  final String Function(ServiceVisit) shopOf;

  const ServiceRecordStrings({
    required this.title,
    required this.bikeLine,
    required this.generatedOn,
    required this.colDate,
    required this.colOdometer,
    required this.colWork,
    required this.colShop,
    required this.colCost,
    required this.totalLine,
    required this.footer,
    required this.formatDate,
    required this.formatKm,
    required this.workOf,
    required this.shopOf,
  });
}

/// A service record a second-hand buyer can read: every visit, oldest
/// first, with receipts appended as photos. CARFAX's resale value, on paper.
///
/// [baseFont] must cover Bengali and ৳ (the bundled Noto Sans Bengali) — the
/// PDF built-ins print blanks for both, see SafeQrScreen._printSticker.
Future<Uint8List> buildServiceRecordPdf({
  required List<ServiceVisit> visits,
  required ServiceRecordStrings s,
  required pw.Font baseFont,
}) async {
  final doc = pw.Document(
    theme: pw.ThemeData.withFont(base: baseFont, bold: baseFont),
  );
  final ordered = List.of(visits)..sort((a, b) => a.date.compareTo(b.date));

  final receipts = <(ServiceVisit, pw.MemoryImage)>[];
  for (final v in ordered) {
    // Through the resolver: iOS moves the app container on update, so a
    // stored absolute path can go stale while the file is still there.
    final path = BikeImageResolver.resolvePathSync(v.receiptPath);
    if (path == null) continue;
    try {
      final f = File(path);
      if (await f.exists()) {
        receipts.add((v, pw.MemoryImage(await f.readAsBytes())));
      }
    } catch (e, st) {
      // A receipt that can't be read is left out, not fatal.
      reportNonFatal(e, st, reason: 'Service record: unreadable receipt');
    }
  }

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(32),
    footer: (ctx) => pw.Text(
      '${s.footer} · ${ctx.pageNumber}/${ctx.pagesCount}',
      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
    ),
    build: (ctx) => [
      pw.Text(s.title,
          style: const pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 4),
      pw.Text(s.bikeLine, style: const pw.TextStyle(fontSize: 12)),
      pw.Text(s.generatedOn,
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
      pw.SizedBox(height: 16),
      pw.TableHelper.fromTextArray(
        headers: [s.colDate, s.colOdometer, s.colWork, s.colShop, s.colCost],
        data: [
          for (final v in ordered)
            [
              s.formatDate(v.date),
              s.formatKm(v.odometerKm),
              s.workOf(v),
              s.shopOf(v),
              v.totalCost == null ? '' : '৳${v.totalCost!.toStringAsFixed(0)}',
            ],
        ],
        headerStyle: const pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
        cellStyle: const pw.TextStyle(fontSize: 9),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
        columnWidths: {
          0: const pw.FixedColumnWidth(70),
          1: const pw.FixedColumnWidth(60),
          2: const pw.FlexColumnWidth(3),
          3: const pw.FlexColumnWidth(1.5),
          4: const pw.FixedColumnWidth(50),
        },
        cellAlignments: {4: pw.Alignment.centerRight},
      ),
      pw.SizedBox(height: 10),
      pw.Text(s.totalLine,
          style: const pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
      for (final (v, img) in receipts) ...[
        pw.NewPage(),
        pw.Text('${s.formatDate(v.date)} · ${s.formatKm(v.odometerKm)}',
            style: const pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Image(img, fit: pw.BoxFit.contain, height: 640),
      ],
    ],
  ));
  return doc.save();
}
