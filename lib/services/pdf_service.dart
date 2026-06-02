import 'dart:io' as io;

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

class PdfService {
  const PdfService();

  Future<void> generateAndShareTablePdf({
    required String title,
    required List<String> headers,
    required List<List<String>> data,
  }) async {
    if (headers.isEmpty) {
      throw ArgumentError('headers cannot be empty');
    }

    final sanitizedRows = data
        .map(
          (row) => row.length == headers.length
              ? row
              : [
                  ...row,
                  ...List.generate(headers.length - row.length, (_) => '-'),
                ].take(headers.length).toList(),
        )
        .toList();

    final pdf = pw.Document();
    final regularFont = await _loadArabicRegularFont();
    final boldFont = await _loadArabicBoldFont();
    final generatedAt = DateTime.now();

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          margin: const pw.EdgeInsets.all(24),
          orientation: pw.PageOrientation.portrait,
          theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont),
        ),
        build: (context) {
          return [
            pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.blue50,
                      borderRadius: pw.BorderRadius.circular(8),
                      border: pw.Border.all(color: PdfColors.blue200),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          title,
                          style: pw.TextStyle(
                            font: boldFont,
                            fontSize: 18,
                            color: PdfColors.blue900,
                          ),
                        ),
                        pw.SizedBox(height: 6),
                        pw.Text(
                          'Generated at: ${_formatDateTime(generatedAt)}',
                          style: const pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 14),
                  pw.TableHelper.fromTextArray(
                    headers: headers,
                    data: sanitizedRows,
                    headerStyle: pw.TextStyle(
                      font: boldFont,
                      color: PdfColors.white,
                      fontSize: 10,
                    ),
                    headerDecoration: const pw.BoxDecoration(
                      color: PdfColors.blue800,
                    ),
                    cellStyle: pw.TextStyle(font: regularFont, fontSize: 9),
                    cellPadding: const pw.EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 5,
                    ),
                    border: pw.TableBorder.all(
                      color: PdfColors.blue100,
                      width: 0.6,
                    ),
                    oddRowDecoration: const pw.BoxDecoration(
                      color: PdfColors.grey100,
                    ),
                    cellAlignments: {
                      for (var i = 0; i < headers.length; i++)
                        i: pw.Alignment.centerRight,
                    },
                  ),
                ],
              ),
            ),
          ];
        },
      ),
    );

    final bytes = await pdf.save();
    await _sharePdfBytes(bytes: bytes, title: title);
  }

  Future<pw.Font> _loadArabicRegularFont() async {
    try {
      return await PdfGoogleFonts.notoNaskhArabicRegular();
    } catch (_) {
      return await PdfGoogleFonts.robotoRegular();
    }
  }

  Future<pw.Font> _loadArabicBoldFont() async {
    try {
      return await PdfGoogleFonts.notoNaskhArabicBold();
    } catch (_) {
      return await PdfGoogleFonts.robotoBold();
    }
  }

  Future<void> _sharePdfBytes({
    required Uint8List bytes,
    required String title,
  }) async {
    final safeName = _safeFileName(title);
    final fileName = '${safeName}_report.pdf';

    if (kIsWeb) {
      await Share.shareXFiles([
        XFile.fromData(bytes, name: fileName, mimeType: 'application/pdf'),
      ], text: 'Here is the exported $title');
      return;
    }

    final tempDir = await getTemporaryDirectory();
    final path = '${tempDir.path}/$fileName';
    final file = io.File(path);
    await file.writeAsBytes(bytes, flush: true);
    final xFile = XFile(file.path);

    await Share.shareXFiles([xFile], text: 'Here is the exported $title');
  }

  String _safeFileName(String value) {
    final normalized = value.trim().replaceAll(RegExp(r'\s+'), '_');
    return normalized.replaceAll(RegExp(r'[^\w\-]'), '');
  }

  String _formatDateTime(DateTime dt) {
    String two(int v) => v.toString().padLeft(2, '0');
    final local = dt.toLocal();
    return '${local.year}/${two(local.month)}/${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
  }
}
