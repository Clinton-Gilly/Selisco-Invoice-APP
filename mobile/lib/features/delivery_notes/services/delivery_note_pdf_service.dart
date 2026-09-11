import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/utils/formatters.dart';
import '../models/delivery_note_model.dart';

/// Exact Selisco logo matching physical receipt:
/// Base horizontal bar, heart outline above it, and solid center teardrop hanging from cleft
const String _seliscoLogoSvg = '''
<svg viewBox="0 0 160 110" xmlns="http://www.w3.org/2000/svg">
  <!-- Bottom horizontal base line -->
  <line x1="20" y1="90" x2="140" y2="90" stroke="#0E7490" stroke-width="6" stroke-linecap="round"/>
  <!-- Heart contour -->
  <path d="M 80,88 C 65,78 40,58 40,38 C 40,22 55,14 69,18 C 75,20 78,25 80,28 C 82,25 85,20 91,18 C 105,14 120,22 120,38 C 120,58 95,78 80,88 Z" 
        fill="none" stroke="#0E7490" stroke-width="5.5" stroke-linecap="round" stroke-linejoin="round"/>
  <!-- Center drop hanging down from top cleft -->
  <path d="M 74,27 L 74,54 C 74,60 76.5,64 80,64 C 83.5,64 86,60 86,54 L 86,27 Z" 
        fill="#0E7490"/>
</svg>
''';

const PdfColor _primaryTeal = PdfColor.fromInt(0xFF0E7490);
const PdfColor _lightTeal = PdfColor.fromInt(0xFFE0F2FE);
const PdfColor _borderTeal = PdfColor.fromInt(0xFF0284C7);

class DeliveryNotePdfService {
  static Future<Uint8List> generateDeliveryNotePdf(DeliveryNoteModel note) async {
    final pdf = pw.Document();

    final verificationUrl =
        '${ApiConstants.verificationBaseUrl}/${note.invoiceId}';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 26),
        build: (pw.Context context) {
          return pw.Stack(
            children: [
              // Central Watermark
              pw.Center(
                child: pw.Opacity(
                  opacity: 0.08,
                  child: pw.Column(
                    mainAxisSize: pw.MainAxisSize.min,
                    children: [
                      pw.SvgImage(
                        svg: _seliscoLogoSvg,
                        width: 170,
                        height: 115,
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        'SELISCO LTD',
                        style: pw.TextStyle(
                          fontSize: 36,
                          fontWeight: pw.FontWeight.bold,
                          color: _primaryTeal,
                          letterSpacing: 2,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Orthopaedic & Surgical',
                        style: pw.TextStyle(
                          fontSize: 22,
                          fontWeight: pw.FontWeight.bold,
                          color: _primaryTeal,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Main Content
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Top Header Row
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      // Left: Logo + Selisco Ltd
                      pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          pw.SvgImage(
                            svg: _seliscoLogoSvg,
                            width: 54,
                            height: 40,
                          ),
                          pw.SizedBox(width: 8),
                          pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                'SELISCO LTD',
                                style: pw.TextStyle(
                                  fontSize: 22,
                                  fontWeight: pw.FontWeight.bold,
                                  color: _primaryTeal,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              pw.Text(
                                'Orthopaedic & Surgical',
                                style: pw.TextStyle(
                                  fontSize: 13,
                                  fontWeight: pw.FontWeight.bold,
                                  color: _primaryTeal,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      // Large, High-Resolution Scannable QR Code
                      pw.Container(
                        padding: const pw.EdgeInsets.all(3),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: _borderTeal, width: 1),
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                          color: PdfColors.white,
                        ),
                        child: pw.BarcodeWidget(
                          barcode: pw.Barcode.qrCode(),
                          data: verificationUrl,
                          width: 76,
                          height: 76,
                        ),
                      ),

                      // Right: Contacts
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            'Tel: 0787371118, 0725822128',
                            style: pw.TextStyle(
                              fontSize: 9.5,
                              fontWeight: pw.FontWeight.bold,
                              color: _primaryTeal,
                            ),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            'Gmail: seliscoltd@gmail.com',
                            style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                              color: _primaryTeal,
                            ),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            'Location: Soy Arcade behind Naivas Trocadero',
                            style: const pw.TextStyle(
                              fontSize: 8.5,
                              color: PdfColors.grey700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  pw.SizedBox(height: 12),

                  pw.Center(
                    child: pw.Text(
                      'OFFICIAL DELIVERY NOTE',
                      style: pw.TextStyle(
                        fontSize: 15,
                        fontWeight: pw.FontWeight.bold,
                        color: _primaryTeal,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),

                  pw.SizedBox(height: 12),

                  // Recipient & Note Details
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'DELIVER TO / HOSPITAL:',
                            style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                              color: _primaryTeal,
                            ),
                          ),
                          pw.SizedBox(height: 3),
                          pw.Text(
                            note.recipientName ?? note.customerName ?? 'Customer',
                            style: pw.TextStyle(
                              fontSize: 13,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.grey900,
                            ),
                          ),
                          if (note.customerPhone != null)
                            pw.Text(
                              note.customerPhone!,
                              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                            ),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            'Note No: ${note.noteNumber}',
                            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _primaryTeal),
                          ),
                          if (note.invoiceNumber != null) ...[
                            pw.SizedBox(height: 2),
                            pw.Text(
                              'Ref Invoice: ${note.invoiceNumber}',
                              style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.grey700),
                            ),
                          ],
                          pw.SizedBox(height: 2),
                          pw.Text(
                            'Date: ${Formatters.date(note.createdAt)}',
                            style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.grey700),
                          ),
                        ],
                      ),
                    ],
                  ),

                  pw.SizedBox(height: 14),

                  // Items Table
                  pw.Container(
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: _borderTeal, width: 1.2),
                    ),
                    child: pw.Column(
                      children: [
                        // Header
                        pw.Container(
                          decoration: const pw.BoxDecoration(
                            border: pw.Border(
                              bottom: pw.BorderSide(color: _borderTeal, width: 1.2),
                            ),
                            color: _lightTeal,
                          ),
                          child: pw.Row(
                            children: [
                              _buildCell('PARTICULARS / ITEM DESCRIPTION', isFlex: true, isHeader: true),
                              _buildCell('ORDERED', width: 75, align: pw.TextAlign.center, isHeader: true),
                              _buildCell('DELIVERED', width: 75, align: pw.TextAlign.center, isHeader: true),
                              _buildCell('STATUS', width: 85, align: pw.TextAlign.center, isHeader: true, isLast: true),
                            ],
                          ),
                        ),

                        // Item Rows
                        ...note.items.map((item) {
                          final isComplete = item.deliveredQuantity >= item.orderedQuantity;
                          return pw.Container(
                            decoration: const pw.BoxDecoration(
                              border: pw.Border(
                                bottom: pw.BorderSide(color: _borderTeal, width: 0.6),
                              ),
                            ),
                            child: pw.Row(
                              children: [
                                _buildCell(item.productName, isFlex: true),
                                _buildCell(item.orderedQuantity.toStringAsFixed(0), width: 75, align: pw.TextAlign.center),
                                _buildCell(item.deliveredQuantity.toStringAsFixed(0), width: 75, align: pw.TextAlign.center),
                                _buildCell(
                                  isComplete ? 'FULFILLED' : 'PARTIAL',
                                  width: 85,
                                  align: pw.TextAlign.center,
                                  isLast: true,
                                  textColor: isComplete ? PdfColors.green800 : PdfColors.amber800,
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),

                  pw.SizedBox(height: 14),

                  // Dispatch Instructions
                  if (note.notes != null && note.notes!.isNotEmpty) ...[
                    pw.Container(
                      width: double.infinity,
                      padding: const pw.EdgeInsets.all(8),
                      decoration: pw.BoxDecoration(
                        color: _lightTeal,
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                        border: pw.Border.all(color: _borderTeal, width: 0.8),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'DISPATCH & SPECIAL INSTRUCTIONS',
                            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _primaryTeal),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(note.notes!, style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey800)),
                        ],
                      ),
                    ),
                    pw.SizedBox(height: 14),
                  ],

                  pw.Spacer(),

                  // Proof of Delivery Acknowledgement Box
                  pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: _borderTeal, width: 1),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'PROOF OF DELIVERY ACKNOWLEDGEMENT',
                          style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: _primaryTeal),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Received the above orthopaedic & surgical goods in full and satisfactory condition.',
                          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                        ),
                        pw.SizedBox(height: 24),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Expanded(
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Container(height: 0.8, color: _borderTeal),
                                  pw.SizedBox(height: 3),
                                  pw.Text('Received By (Name / Stamp)', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
                                ],
                              ),
                            ),
                            pw.SizedBox(width: 36),
                            pw.Expanded(
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Container(height: 0.8, color: _borderTeal),
                                  pw.SizedBox(height: 3),
                                  pw.Text('Authorized Signature & Date', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  pw.SizedBox(height: 10),

                  // Bottom Footer: Powered by Xuremi +254715329007
                  pw.Center(
                    child: pw.Text(
                      'Powered by Xuremi • +254715329007',
                      style: pw.TextStyle(
                        fontSize: 9.5,
                        fontWeight: pw.FontWeight.bold,
                        color: _primaryTeal,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildCell(
    String text, {
    double? width,
    bool isFlex = false,
    pw.TextAlign align = pw.TextAlign.left,
    bool isHeader = false,
    bool isLast = false,
    PdfColor? textColor,
  }) {
    final border = isLast
        ? null
        : const pw.Border(right: pw.BorderSide(color: _borderTeal, width: 0.8));

    final content = pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 6),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: isHeader ? 9.5 : 9,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: textColor ?? (isHeader ? _primaryTeal : PdfColors.grey900),
        ),
      ),
    );

    if (isFlex) {
      return pw.Expanded(
        child: pw.Container(decoration: pw.BoxDecoration(border: border), child: content),
      );
    }
    return pw.Container(
      width: width,
      decoration: pw.BoxDecoration(border: border),
      child: content,
    );
  }

  static Future<void> printOrShareDeliveryNote(BuildContext context, DeliveryNoteModel note) async {
    final pdfBytes = await generateDeliveryNotePdf(note);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: '${note.noteNumber}.pdf',
    );
  }

  static Future<void> shareDeliveryNotePdf(DeliveryNoteModel note) async {
    final pdfBytes = await generateDeliveryNotePdf(note);
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: '${note.noteNumber}.pdf',
    );
  }
}
