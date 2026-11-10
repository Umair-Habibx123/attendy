import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../core/config.dart';
import '../core/dates.dart';
import 'report.dart';

/// Turns a report into a CSV or PDF file and opens the share sheet
/// (save to Files, Drive, email, WhatsApp, and so on).
class ReportExporter {
  const ReportExporter();

  Future<void> shareCsv(AttendanceReport report) async {
    // A byte-order mark makes Excel open the UTF-8 file with the right characters.
    final bytes = Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(report.toCsv())]);
    await _share(bytes, '${_fileStem(report)}.csv', 'text/csv', report.title);
  }

  Future<void> sharePdf(AttendanceReport report) async {
    await _share(await buildPdf(report), '${_fileStem(report)}.pdf', 'application/pdf', report.title);
  }

  Future<Uint8List> buildPdf(AttendanceReport report) async {
    final doc = pw.Document(title: report.title, author: AppConfig.appName);
    final generated = DateFormat('d MMM yyyy, HH:mm').format(report.generatedAt);
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('${AppConfig.appName} attendance report',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text(
              '${DateFormat('d MMM yyyy').format(report.from)} to ${DateFormat('d MMM yyyy').format(report.to)}'
              '  ·  ${Dates.workingDaysBetween(report.from, report.to).length} working days  ·  generated $generated',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 14),
          ],
        ),
        footer: (ctx) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
        ),
        build: (_) => [
          if (report.rows.isEmpty)
            pw.Text('No users in this report.')
          else
            pw.TableHelper.fromTextArray(
              headers: AttendanceReport.headers,
              data: report.table,
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
              headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF4F46E5)),
              cellStyle: const pw.TextStyle(fontSize: 9),
              oddRowDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF1F5F9)),
              cellAlignments: {for (var i = 2; i < 6; i++) i: pw.Alignment.centerRight},
            ),
          pw.SizedBox(height: 10),
          pw.Text(
            'Absent includes working days with no attendance recorded. '
            'Attendance % = present ÷ (present + absent); approved leave is not counted against it.',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
        ],
      ),
    );
    return doc.save();
  }

  String _fileStem(AttendanceReport r) =>
      'attendy-report-${Dates.dayKey(r.from)}-to-${Dates.dayKey(r.to)}';

  Future<void> _share(Uint8List bytes, String name, String mime, String subject) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(bytes, flush: true);
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path, mimeType: mime, name: name)],
      subject: subject,
    ));
  }
}
