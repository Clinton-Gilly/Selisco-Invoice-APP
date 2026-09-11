import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/utils/formatters.dart';
import '../models/invoice_model.dart';

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
const PdfColor _redNoColor = PdfColor.fromInt(0xFFDC2626);

class InvoicePdfService {
  static Future<Uint8List> generateInvoicePdf(InvoiceModel invoice) async {
    final pdf = pw.Document();

    final verificationUrl =
        '${ApiConstants.verificationBaseUrl}/${invoice.id}';

    // Calculate minimum rows to render receipt grid look (at least 8 rows)
    final int emptyRowsNeeded = (8 - invoice.items.length).clamp(0, 8);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 26),
        build: (pw.Context context) {
          return pw.Stack(
            children: [
              // Central Watermark: Exact Selisco Logo & Title in soft opacity
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

              // Document Content
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Top Header: Logo + Title + Prominent QR Code + Contacts
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      // Left: Logo & Company Name
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

                      // Large, High-Resolution Scannable QR Code next to Selisco Ltd
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

                  // Document Title: RECEIPT / TAX INVOICE
                  pw.Center(
                    child: pw.Text(
                      'RECEIPT / TAX INVOICE',
                      style: pw.TextStyle(
                        fontSize: 15,
                        fontWeight: pw.FontWeight.bold,
                        color: _primaryTeal,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),

                  pw.SizedBox(height: 10),

                  // M/s, PIN & Date Row
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Expanded(
                        child: pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            pw.Text(
                              'M/s / Hospital: ',
                              style: pw.TextStyle(
                                fontSize: 11,
                                fontWeight: pw.FontWeight.bold,
                                color: _primaryTeal,
                              ),
                            ),
                            pw.Expanded(
                              child: pw.Container(
                                padding: const pw.EdgeInsets.only(bottom: 2, left: 4),
                                decoration: const pw.BoxDecoration(
                                  border: pw.Border(
                                    bottom: pw.BorderSide(color: _borderTeal, width: 0.8),
                                  ),
                                ),
                                child: pw.Text(
                                  invoice.customerName,
                                  style: pw.TextStyle(
                                    fontSize: 12,
                                    fontWeight: pw.FontWeight.bold,
                                    color: PdfColors.grey900,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      pw.SizedBox(width: 24),
                      pw.Row(
                        children: [
                          pw.Text(
                            'Date: ',
                            style: pw.TextStyle(
                              fontSize: 11,
                              fontWeight: pw.FontWeight.bold,
                              color: _primaryTeal,
                            ),
                          ),
                          pw.Container(
                            padding: const pw.EdgeInsets.only(bottom: 2, left: 4, right: 8),
                            decoration: const pw.BoxDecoration(
                              border: pw.Border(
                                bottom: pw.BorderSide(color: _borderTeal, width: 0.8),
                              ),
                            ),
                            child: pw.Text(
                              Formatters.date(invoice.issuedDate),
                              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Optional Company / KRA PIN
                  if (invoice.customerPin != null && invoice.customerPin!.isNotEmpty) ...[
                    pw.SizedBox(height: 6),
                    pw.Row(
                      children: [
                        pw.Text(
                          'Company / KRA PIN: ',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: _primaryTeal,
                          ),
                        ),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: pw.BoxDecoration(
                            color: _lightTeal,
                            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                          ),
                          child: pw.Text(
                            invoice.customerPin!,
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                              color: _primaryTeal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  pw.SizedBox(height: 12),

                  // Table Grid (Styled matching receipt image)
                  pw.Container(
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: _borderTeal, width: 1.2),
                    ),
                    child: pw.Column(
                      children: [
                        // Header Row: QTY. | PARTICULARS | @ | Shs.
                        pw.Container(
                          decoration: const pw.BoxDecoration(
                            border: pw.Border(
                              bottom: pw.BorderSide(color: _borderTeal, width: 1.2),
                            ),
                            color: _lightTeal,
                          ),
                          child: pw.Row(
                            children: [
                              _buildGridCell('QTY.', width: 48, align: pw.TextAlign.center, isHeader: true),
                              _buildGridCell('PARTICULARS', isFlex: true, align: pw.TextAlign.center, isHeader: true),
                              _buildGridCell('@', width: 85, align: pw.TextAlign.center, isHeader: true),
                              _buildGridCell('Shs.', width: 95, align: pw.TextAlign.center, isHeader: true, isLast: true),
                            ],
                          ),
                        ),

                        // Line Items Rows
                        ...invoice.items.map((item) {
                          return pw.Container(
                            decoration: const pw.BoxDecoration(
                              border: pw.Border(
                                bottom: pw.BorderSide(color: _borderTeal, width: 0.6),
                              ),
                            ),
                            child: pw.Row(
                              children: [
                                _buildGridCell(
                                  item.quantity.toStringAsFixed(0),
                                  width: 48,
                                  align: pw.TextAlign.center,
                                ),
                                _buildGridCell(
                                  item.productName,
                                  isFlex: true,
                                  subtitle: item.description,
                                ),
                                _buildGridCell(
                                  Formatters.currency(item.unitPrice, currencyCode: invoice.currency),
                                  width: 85,
                                  align: pw.TextAlign.right,
                                ),
                                _buildGridCell(
                                  Formatters.currency(item.totalPrice, currencyCode: invoice.currency),
                                  width: 95,
                                  align: pw.TextAlign.right,
                                  isLast: true,
                                ),
                              ],
                            ),
                          );
                        }),

                        // Empty blank rows to preserve authentic pad feel
                        ...List.generate(emptyRowsNeeded, (_) {
                          return pw.Container(
                            height: 22,
                            decoration: const pw.BoxDecoration(
                              border: pw.Border(
                                bottom: pw.BorderSide(color: _borderTeal, width: 0.5),
                              ),
                            ),
                            child: pw.Row(
                              children: [
                                _buildEmptyCell(width: 48),
                                _buildEmptyCell(isFlex: true),
                                _buildEmptyCell(width: 85),
                                _buildEmptyCell(width: 95, isLast: true),
                              ],
                            ),
                          );
                        }),

                        // Bottom Row: E&O.E | No. | TOTAL
                        pw.Container(
                          height: 32,
                          child: pw.Row(
                            children: [
                              // E&O.E
                              pw.Container(
                                width: 65,
                                padding: const pw.EdgeInsets.symmetric(horizontal: 6),
                                alignment: pw.Alignment.centerLeft,
                                decoration: const pw.BoxDecoration(
                                  border: pw.Border(
                                    right: pw.BorderSide(color: _borderTeal, width: 1),
                                  ),
                                ),
                                child: pw.Text(
                                  'E&O.E',
                                  style: pw.TextStyle(
                                    fontSize: 9,
                                    fontWeight: pw.FontWeight.bold,
                                    color: _primaryTeal,
                                  ),
                                ),
                              ),
                              // Red Receipt No.
                              pw.Container(
                                width: 130,
                                padding: const pw.EdgeInsets.symmetric(horizontal: 8),
                                alignment: pw.Alignment.centerLeft,
                                decoration: const pw.BoxDecoration(
                                  border: pw.Border(
                                    right: pw.BorderSide(color: _borderTeal, width: 1),
                                  ),
                                ),
                                child: pw.Row(
                                  children: [
                                    pw.Text(
                                      'No. ',
                                      style: pw.TextStyle(fontSize: 10, color: _primaryTeal, fontWeight: pw.FontWeight.bold),
                                    ),
                                    pw.Text(
                                      invoice.invoiceNumber,
                                      style: pw.TextStyle(
                                        fontSize: 11,
                                        fontWeight: pw.FontWeight.bold,
                                        color: _redNoColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // TOTAL Label
                              pw.Expanded(
                                child: pw.Container(
                                  padding: const pw.EdgeInsets.only(right: 12),
                                  alignment: pw.Alignment.centerRight,
                                  child: pw.Text(
                                    'TOTAL',
                                    style: pw.TextStyle(
                                      fontSize: 12,
                                      fontWeight: pw.FontWeight.bold,
                                      color: _primaryTeal,
                                    ),
                                  ),
                                ),
                              ),
                              // TOTAL Value
                              pw.Container(
                                width: 120,
                                padding: const pw.EdgeInsets.symmetric(horizontal: 8),
                                alignment: pw.Alignment.centerRight,
                                decoration: const pw.BoxDecoration(
                                  border: pw.Border(
                                    left: pw.BorderSide(color: _borderTeal, width: 1),
                                  ),
                                  color: _lightTeal,
                                ),
                                child: pw.Text(
                                  Formatters.currency(invoice.totalAmount, currencyCode: invoice.currency),
                                  style: pw.TextStyle(
                                    fontSize: 13,
                                    fontWeight: pw.FontWeight.bold,
                                    color: _primaryTeal,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  pw.SizedBox(height: 8),

                  // Centered Subtext: ACCOUNT ARE DUE ON DEMAND
                  pw.Center(
                    child: pw.Text(
                      'ACCOUNT ARE DUE ON DEMAND',
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                        color: _primaryTeal,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),

                  pw.Spacer(),

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

  static pw.Widget _buildGridCell(
    String text, {
    double? width,
    bool isFlex = false,
    pw.TextAlign align = pw.TextAlign.left,
    bool isHeader = false,
    bool isLast = false,
    String? subtitle,
  }) {
    final cellContent = pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 6),
      child: pw.Column(
        crossAxisAlignment: align == pw.TextAlign.right
            ? pw.CrossAxisAlignment.end
            : align == pw.TextAlign.center
                ? pw.CrossAxisAlignment.center
                : pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            text,
            textAlign: align,
            style: pw.TextStyle(
              fontSize: isHeader ? 10 : 9.5,
              fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: isHeader ? _primaryTeal : PdfColors.grey900,
            ),
          ),
          if (subtitle != null && subtitle.isNotEmpty) ...[
            pw.SizedBox(height: 1),
            pw.Text(
              subtitle,
              textAlign: align,
              style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
            ),
          ],
        ],
      ),
    );

    final border = isLast
        ? null
        : const pw.Border(right: pw.BorderSide(color: _borderTeal, width: 0.8));

    if (isFlex) {
      return pw.Expanded(
        child: pw.Container(
          decoration: pw.BoxDecoration(border: border),
          child: cellContent,
        ),
      );
    }

    return pw.Container(
      width: width,
      decoration: pw.BoxDecoration(border: border),
      child: cellContent,
    );
  }

  static pw.Widget _buildEmptyCell({double? width, bool isFlex = false, bool isLast = false}) {
    final border = isLast
        ? null
        : const pw.Border(right: pw.BorderSide(color: _borderTeal, width: 0.8));

    if (isFlex) {
      return pw.Expanded(
        child: pw.Container(decoration: pw.BoxDecoration(border: border)),
      );
    }
    return pw.Container(
      width: width,
      decoration: pw.BoxDecoration(border: border),
    );
  }

  static Future<void> printOrShareInvoice(BuildContext context, InvoiceModel invoice) async {
    final pdfBytes = await generateInvoicePdf(invoice);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: '${invoice.invoiceNumber}.pdf',
    );
  }

  static Future<void> shareInvoicePdf(InvoiceModel invoice) async {
    final pdfBytes = await generateInvoicePdf(invoice);
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: '${invoice.invoiceNumber}.pdf',
    );
  }
}
