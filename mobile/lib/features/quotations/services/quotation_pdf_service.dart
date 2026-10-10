import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/utils/formatters.dart';
import '../models/quotation_model.dart';

/// Selisco heart logo, same artwork as the invoice and delivery note PDFs.
const String _seliscoLogoSvg = '''
<svg viewBox="0 0 160 110" xmlns="http://www.w3.org/2000/svg">
  <line x1="20" y1="90" x2="140" y2="90" stroke="#0E7490" stroke-width="6" stroke-linecap="round"/>
  <path d="M 80,88 C 65,78 40,58 40,38 C 40,22 55,14 69,18 C 75,20 78,25 80,28 C 82,25 85,20 91,18 C 105,14 120,22 120,38 C 120,58 95,78 80,88 Z"
        fill="none" stroke="#0E7490" stroke-width="5.5" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="M 74,27 L 74,54 C 74,60 76.5,64 80,64 C 83.5,64 86,60 86,54 L 86,27 Z" fill="#0E7490"/>
</svg>
''';

const PdfColor _primaryTeal = PdfColor.fromInt(0xFF0E7490);
const PdfColor _lightTeal = PdfColor.fromInt(0xFFE0F2FE);
const PdfColor _borderTeal = PdfColor.fromInt(0xFF0284C7);
const PdfColor _redNoColor = PdfColor.fromInt(0xFFDC2626);

const double _qtyWidth = 44;
const double _priceWidth = 88;
const double _amountWidth = 100;
const int _minRows = 12;

/// Renders a quotation laid out like the printed Selisco quotation pad:
/// header with contacts, Quote #/dates, "TO" line, QTY | Description |
/// Unit Price | Amount grid, red quote number with TOTAL, then terms and signature.
class QuotationPdfService {
  static Future<Uint8List> generateQuotationPdf(QuotationModel quote) async {
    final pdf = pw.Document();
    String money(num v) => Formatters.currency(v, currencyCode: quote.currency);
    final emptyRows = (_minRows - quote.items.length).clamp(0, _minRows);

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 28),
          buildBackground: (context) => pw.Center(
            child: pw.Opacity(
              opacity: 0.06,
              child: pw.SvgImage(svg: _seliscoLogoSvg, width: 260, height: 180),
            ),
          ),
        ),
        footer: (context) => pw.Center(
          child: pw.Text(
            'Powered by Xuremi  |  +254715329007',
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _primaryTeal),
          ),
        ),
        build: (context) => [
          _buildHeader(),
          pw.SizedBox(height: 10),
          _buildTitleAndMeta(quote),
          pw.SizedBox(height: 14),
          _buildToLine(quote),
          pw.SizedBox(height: 14),
          _buildItemsTable(quote, emptyRows, money),
          _buildTotalRow(quote, money),
          pw.SizedBox(height: 22),
          _buildTermsAndSignature(quote),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildHeader() {
    return pw.Column(
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.SvgImage(svg: _seliscoLogoSvg, width: 62, height: 44),
            pw.SizedBox(width: 10),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'SELISCO',
                  style: pw.TextStyle(
                    fontSize: 30,
                    fontWeight: pw.FontWeight.bold,
                    color: _primaryTeal,
                    letterSpacing: 2,
                  ),
                ),
                pw.Text(
                  'Orthopaedic & Surgical',
                  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: _primaryTeal),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          'Tel: 0787 371 118  |  0725 822 128',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.grey900),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          'seliscoltd@gmail.com  |  Soy Arcade behind Naivas Trocadero',
          style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700),
        ),
      ],
    );
  }

  static pw.Widget _buildTitleAndMeta(QuotationModel quote) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Expanded(
          child: pw.Text(
            'QUOTATION',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              fontSize: 22,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey900,
              letterSpacing: 2,
            ),
          ),
        ),
        pw.SizedBox(
          width: 190,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _metaLine('Quote #', quote.quoteNumber),
              _metaLine('Quote Date', Formatters.date(quote.quoteDate)),
              _metaLine('Due Date', Formatters.date(quote.dueDate)),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _metaLine(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.SizedBox(
            width: 70,
            child: pw.Text(label, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          ),
          pw.Expanded(
            child: pw.Container(
              padding: const pw.EdgeInsets.only(left: 4, bottom: 1),
              decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey600, width: 0.6, style: pw.BorderStyle.dotted)),
              ),
              child: pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildToLine(QuotationModel quote) {
    final contacts = [quote.customerPhone, quote.customerEmail]
        .where((c) => c != null && c.trim().isNotEmpty)
        .join('   |   ');
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text('TO: ', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.Expanded(
              child: pw.Container(
                padding: const pw.EdgeInsets.only(left: 4, bottom: 2),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey600, width: 0.6, style: pw.BorderStyle.dotted)),
                ),
                child: pw.Text(
                  quote.customerName,
                  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.grey900),
                ),
              ),
            ),
          ],
        ),
        if (contacts.isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(left: 30, top: 3),
            child: pw.Text(contacts, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
          ),
      ],
    );
  }

  static pw.Widget _buildItemsTable(QuotationModel quote, int emptyRows, String Function(num) money) {
    pw.Widget cell(String text, {pw.TextAlign align = pw.TextAlign.left, bool header = false, String? sub}) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
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
                fontSize: header ? 10 : 9.5,
                fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal,
                color: header ? _primaryTeal : PdfColors.grey900,
              ),
            ),
            if (sub != null && sub.isNotEmpty)
              pw.Text(sub, textAlign: align, style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600)),
          ],
        ),
      );
    }

    String qty(double q) => q % 1 == 0 ? q.toStringAsFixed(0) : q.toString();

    return pw.Table(
      border: const pw.TableBorder(
        left: pw.BorderSide(color: _borderTeal, width: 1.2),
        right: pw.BorderSide(color: _borderTeal, width: 1.2),
        top: pw.BorderSide(color: _borderTeal, width: 1.2),
        bottom: pw.BorderSide(color: _borderTeal, width: 0.6),
        horizontalInside: pw.BorderSide(color: _borderTeal, width: 0.5),
        verticalInside: pw.BorderSide(color: _borderTeal, width: 0.8),
      ),
      columnWidths: const {
        0: pw.FixedColumnWidth(_qtyWidth),
        1: pw.FlexColumnWidth(),
        2: pw.FixedColumnWidth(_priceWidth),
        3: pw.FixedColumnWidth(_amountWidth),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _lightTeal),
          repeat: true,
          children: [
            cell('QTY', align: pw.TextAlign.center, header: true),
            cell('Description', header: true),
            cell('Unit Price', align: pw.TextAlign.center, header: true),
            cell('Amount', align: pw.TextAlign.center, header: true),
          ],
        ),
        ...quote.items.map(
          (item) => pw.TableRow(
            children: [
              cell(qty(item.quantity), align: pw.TextAlign.center),
              cell(item.productName, sub: item.description),
              cell(money(item.unitPrice), align: pw.TextAlign.right),
              cell(money(item.totalPrice), align: pw.TextAlign.right),
            ],
          ),
        ),
        ...List.generate(
          emptyRows,
          (_) => pw.TableRow(
            children: List.generate(4, (_) => pw.SizedBox(height: 20)),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildTotalRow(QuotationModel quote, String Function(num) money) {
    const side = pw.BorderSide(color: _borderTeal, width: 1.2);
    pw.Widget labelValue(String label, String value, {bool emphasize = false}) {
      return pw.Row(
        children: [
          pw.Container(
            width: _priceWidth,
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: emphasize ? 12 : 9.5,
                fontWeight: pw.FontWeight.bold,
                color: _primaryTeal,
              ),
            ),
          ),
          pw.Container(
            width: _amountWidth,
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            alignment: pw.Alignment.centerRight,
            decoration: pw.BoxDecoration(
              color: emphasize ? _lightTeal : null,
              border: const pw.Border(left: pw.BorderSide(color: _borderTeal, width: 0.8)),
            ),
            child: pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: emphasize ? 12 : 9.5,
                fontWeight: pw.FontWeight.bold,
                color: emphasize ? _primaryTeal : PdfColors.grey900,
              ),
            ),
          ),
        ],
      );
    }

    return pw.Container(
      decoration: const pw.BoxDecoration(border: pw.Border(left: side, right: side, bottom: side)),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          // The quotation's number, printed in red like the serial on the paper pad
          pw.Expanded(
            child: pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: pw.Row(
                children: [
                  pw.Text('No. ', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _primaryTeal)),
                  pw.Text(
                    quote.quoteNumber,
                    style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: _redNoColor),
                  ),
                ],
              ),
            ),
          ),
          pw.Container(
            decoration: const pw.BoxDecoration(border: pw.Border(left: pw.BorderSide(color: _borderTeal, width: 0.8))),
            child: pw.Column(
              children: [
                if (quote.tax > 0) ...[
                  labelValue('Subtotal', money(quote.subtotal)),
                  labelValue('Tax', money(quote.tax)),
                ],
                labelValue('TOTAL', money(quote.totalAmount), emphasize: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildTermsAndSignature(QuotationModel quote) {
    final terms = (quote.terms == null || quote.terms!.trim().isEmpty)
        ? 'Payment is due within 14 days.\nPlease make cheques payable to SELISCO LTD.'
        : quote.terms!.trim();
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Terms and Conditions', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Text(terms, style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.grey800, lineSpacing: 2)),
            ],
          ),
        ),
        pw.SizedBox(width: 30),
        pw.Column(
          children: [
            pw.Container(
              width: 160,
              decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey700, width: 0.8)),
              ),
              height: 30,
            ),
            pw.SizedBox(height: 3),
            pw.Text('Signature', style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.grey800)),
          ],
        ),
      ],
    );
  }

  static Future<void> printQuotation(QuotationModel quote) async {
    final bytes = await generateQuotationPdf(quote);
    await Printing.layoutPdf(onLayout: (_) async => bytes, name: '${quote.quoteNumber}.pdf');
  }

  static Future<void> shareQuotationPdf(QuotationModel quote) async {
    final bytes = await generateQuotationPdf(quote);
    await Printing.sharePdf(bytes: bytes, filename: 'Quotation-${quote.quoteNumber}.pdf');
  }
}
