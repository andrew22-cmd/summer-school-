import 'package:intl/intl.dart';

import 'package:flutter/foundation.dart';
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

  /// Generates and shares a fully Arabic, RTL attendance PDF.
  ///
  /// [arabicDayName]  – e.g. "الإثنين"
  /// [arabicDateStr]  – e.g. "03-06-2026"
  /// [title]          – heading shown in the PDF header card.
  ///                    Defaults to "تقرير الحضور والغياب اليومي".
  /// [fileNamePrefix] – Arabic prefix used before day/date in the filename.
  ///                    Defaults to "تقرير_حضور".
  Future<void> generateAndShareAttendancePdf({
    required String arabicDayName,
    required String arabicDateStr,
    required List<String> headers,
    required List<List<String>> data,
    String title = 'تقرير الحضور والغياب اليومي',
    String fileNamePrefix = 'تقرير_حضور',
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
                  // ── Header card ──────────────────────────────────────
                  pw.Container(
                    padding: const pw.EdgeInsets.all(14),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.blue50,
                      borderRadius: pw.BorderRadius.circular(8),
                      border: pw.Border.all(color: PdfColors.blue200),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        // Main Arabic title
                        pw.Text(
                          title,
                          style: pw.TextStyle(
                            font: boldFont,
                            fontSize: 18,
                            color: PdfColors.blue900,
                          ),
                        ),
                        pw.SizedBox(height: 8),
                        // Day + Date row
                        pw.Row(
                          children: [
                            pw.Text(
                              'اليوم: $arabicDayName',
                              style: pw.TextStyle(
                                font: regularFont,
                                fontSize: 11,
                                color: PdfColors.grey700,
                              ),
                            ),
                            pw.SizedBox(width: 24),
                            pw.Text(
                              'التاريخ: $arabicDateStr',
                              style: pw.TextStyle(
                                font: regularFont,
                                fontSize: 11,
                                color: PdfColors.grey700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 14),
                  // ── Data table ───────────────────────────────────────
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
    // Dynamic Arabic file name
    final fileName = '${fileNamePrefix}_${arabicDayName}_$arabicDateStr.pdf';
    await _sharePdfBytesWithName(bytes: bytes, fileName: fileName);
  }

  /// Generates and shares a fully Arabic, RTL points-history PDF.
  ///
  /// [studentName]   – full Arabic/English name of the student
  /// [studentCode]   – the student's ID used as a code
  /// [currentPoints] – the live total balance
  /// [data]          – rows: [date, points, reason, addedBy]
  Future<void> generateAndSharePointsPdf({
    required String studentName,
    required String studentCode,
    required int currentPoints,
    required List<List<String>> data,
  }) async {
    const headers = ['التاريخ', 'النقاط', 'السبب / البيان', 'بواسطة'];

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
                  // ── Header card ──────────────────────────────────────
                  pw.Container(
                    padding: const pw.EdgeInsets.all(14),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.blue50,
                      borderRadius: pw.BorderRadius.circular(8),
                      border: pw.Border.all(color: PdfColors.blue200),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        // Main Arabic title
                        pw.Text(
                          'تقرير سجل النقاط والتقييم (Points History)',
                          style: pw.TextStyle(
                            font: boldFont,
                            fontSize: 16,
                            color: PdfColors.blue900,
                          ),
                        ),
                        pw.SizedBox(height: 10),
                        // Student info row
                        pw.Wrap(
                          spacing: 24,
                          runSpacing: 4,
                          children: [
                            pw.Text(
                              'اسم الطالب: $studentName',
                              style: pw.TextStyle(
                                font: regularFont,
                                fontSize: 11,
                                color: PdfColors.grey700,
                              ),
                            ),
                            pw.Text(
                              'الكود: $studentCode',
                              style: pw.TextStyle(
                                font: regularFont,
                                fontSize: 11,
                                color: PdfColors.grey700,
                              ),
                            ),
                            pw.Text(
                              'الرصيد الحالي: $currentPoints نقطة',
                              style: pw.TextStyle(
                                font: boldFont,
                                fontSize: 11,
                                color: currentPoints >= 0
                                    ? PdfColors.green800
                                    : PdfColors.red800,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 14),
                  // ── Data table ───────────────────────────────────────
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
    final dateStr = DateFormat('dd-MM-yyyy').format(DateTime.now());
    final fileName = 'سجل_نقاط_${studentName}_$dateStr.pdf';
    await _sharePdfBytesWithName(bytes: bytes, fileName: fileName);
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
    await _sharePdfBytesWithName(bytes: bytes, fileName: fileName);
  }

  Future<void> _sharePdfBytesWithName({
    required Uint8List bytes,
    required String fileName,
  }) async {
    await Share.shareXFiles([
      XFile.fromData(bytes, name: fileName, mimeType: 'application/pdf'),
    ]);
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
