import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_exceptions.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../copilot/presentation/screens/copilot_sheet.dart';
import '../../../copilot/services/screen_context_service.dart';
import '../../../invoices/presentation/controllers/invoice_providers.dart';
import '../../../invoices/presentation/screens/invoice_detail_screen.dart';
import '../../data/quotation_repository.dart';
import '../../models/quotation_model.dart';
import '../../services/quotation_pdf_service.dart';
import '../controllers/quotation_providers.dart';

class QuotationDetailScreen extends ConsumerStatefulWidget {
  final String quotationId;

  const QuotationDetailScreen({super.key, required this.quotationId});

  @override
  ConsumerState<QuotationDetailScreen> createState() => _QuotationDetailScreenState();
}

class _QuotationDetailScreenState extends ConsumerState<QuotationDetailScreen> {
  bool _busy = false;

  String _errorText(Object e) => e is ApiException ? e.message : e.toString().replaceAll('Exception: ', '');

  void _showError(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: AppColors.error, content: Text(_errorText(e))),
    );
  }

  void _refresh() {
    ref.invalidate(quotationDetailProvider(widget.quotationId));
    ref.invalidate(quotationsListProvider);
  }

  Future<void> _setStatus(String status) async {
    setState(() => _busy = true);
    try {
      await ref.read(quotationRepositoryProvider).updateStatus(widget.quotationId, status);
      _refresh();
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _convert(QuotationModel quote) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Create Invoice?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          'An invoice for ${quote.customerName} totalling '
          '${Formatters.currency(quote.totalAmount, currencyCode: quote.currency)} will be issued '
          'with the same ${quote.items.length} item(s). The quotation will be marked as invoiced.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(dCtx, true), child: const Text('Create Invoice')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      final invoiceId = await ref.read(quotationRepositoryProvider).convertToInvoice(quote.id);
      _refresh();
      ref.invalidate(invoicesListProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: AppColors.success, content: Text('Invoice created from quotation.')),
      );
      Navigator.push(context, MaterialPageRoute(builder: (_) => InvoiceDetailScreen(invoiceId: invoiceId)));
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(QuotationModel quote) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Delete quotation?'),
        content: Text('${quote.quoteNumber} for ${quote.customerName} will be permanently removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(dCtx, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(quotationRepositoryProvider).deleteQuotation(quote.id);
      ref.invalidate(quotationsListProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _showError(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final quoteAsync = ref.watch(quotationDetailProvider(widget.quotationId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quotation'),
        actions: [
          if (quoteAsync.hasValue) ...[
            IconButton(
              icon: const Icon(Icons.auto_awesome, color: AppColors.primary),
              tooltip: 'Copilot Assistant',
              onPressed: () {
                final q = quoteAsync.value!;
                ref.read(screenContextProvider.notifier).updateScreen(
                      route: '/quotations/detail',
                      screenName: 'Quotation Details',
                      activeRecord: {
                        'id': q.id,
                        'quote_number': q.quoteNumber,
                        'customer_name': q.customerName,
                        'status': q.status,
                        'total_amount': q.totalAmount,
                      },
                      customNote: 'Viewing quotation ${q.quoteNumber} for ${q.customerName}.',
                    );
                CopilotSheet.show(context);
              },
            ),
            IconButton(
              icon: const Icon(Icons.share_outlined),
              tooltip: 'Share PDF',
              onPressed: () => QuotationPdfService.shareQuotationPdf(quoteAsync.value!),
            ),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'delete') _delete(quoteAsync.value!);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete quotation', style: TextStyle(color: AppColors.error)),
                ),
              ],
            ),
          ],
        ],
      ),
      body: quoteAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (err, _) => Center(child: Text('Error: ${_errorText(err)}')),
        data: (quote) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildHeaderCard(quote),
            const SizedBox(height: 16),
            _buildItemsCard(quote),
            if (quote.terms != null && quote.terms!.trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Terms and Conditions', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text(quote.terms!, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            ..._buildActions(quote),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(QuotationModel quote) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(quote.quoteNumber, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              StatusBadge(status: quote.status),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            quote.customerName,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
          ),
          if (quote.customerPhone != null && quote.customerPhone!.isNotEmpty)
            Text(quote.customerPhone!, style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
          if (quote.customerEmail != null && quote.customerEmail!.isNotEmpty)
            Text(quote.customerEmail!, style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _dateColumn('Quote Date', quote.quoteDate, CrossAxisAlignment.start),
              _dateColumn('Due Date', quote.dueDate, CrossAxisAlignment.end),
            ],
          ),
          if (quote.invoiceNumber != null) ...[
            const SizedBox(height: 12),
            InkWell(
              onTap: quote.invoiceId == null
                  ? null
                  : () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => InvoiceDetailScreen(invoiceId: quote.invoiceId!)),
                      ),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long, size: 16, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Invoiced as ${quote.invoiceNumber}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _dateColumn(String label, String value, CrossAxisAlignment align) {
    return Column(
      crossAxisAlignment: align,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
        Text(Formatters.date(value), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildItemsCard(QuotationModel quote) {
    String money(num v) => Formatters.currency(v, currencyCode: quote.currency);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Items', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ),
          const Divider(height: 1),
          ...quote.items.map(
            (item) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.productName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        if (item.description != null && item.description!.isNotEmpty)
                          Text(item.description!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        const SizedBox(height: 4),
                        Text(
                          '${item.quantity % 1 == 0 ? item.quantity.toStringAsFixed(0) : item.quantity} × ${money(item.unitPrice)}',
                          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      money(item.totalPrice),
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (quote.tax > 0) ...[
                  _amountRow('Subtotal', money(quote.subtotal)),
                  const SizedBox(height: 6),
                  _amountRow('Tax', money(quote.tax)),
                  const SizedBox(height: 10),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(
                      money(quote.totalAmount),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.primary),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _amountRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary)),
        Text(value),
      ],
    );
  }

  List<Widget> _buildActions(QuotationModel quote) {
    return [
      SizedBox(
        height: 52,
        child: ElevatedButton.icon(
          onPressed: () => QuotationPdfService.shareQuotationPdf(quote),
          icon: const Icon(Icons.share_rounded, size: 20),
          label: const Text('Share Quotation (WhatsApp, Email...)', style: TextStyle(fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF059669),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      const SizedBox(height: 12),
      SizedBox(
        height: 48,
        child: OutlinedButton.icon(
          onPressed: () => QuotationPdfService.printQuotation(quote),
          icon: const Icon(Icons.picture_as_pdf_outlined),
          label: const Text('View / Print A4 PDF'),
        ),
      ),
      if (quote.canConvert) ...[
        const SizedBox(height: 12),
        SizedBox(
          height: 48,
          child: OutlinedButton.icon(
            onPressed: _busy ? null : () => _convert(quote),
            icon: _busy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.receipt_long_outlined),
            label: const Text('Convert to Invoice'),
          ),
        ),
      ],
      if (quote.status != 'INVOICED') ...[
        const SizedBox(height: 8),
        Row(
          children: [
            if (quote.status != 'ACCEPTED')
              Expanded(
                child: TextButton.icon(
                  onPressed: _busy ? null : () => _setStatus('ACCEPTED'),
                  icon: const Icon(Icons.thumb_up_alt_outlined, color: AppColors.success),
                  label: const Text('Accepted', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold)),
                ),
              ),
            if (quote.status != 'DECLINED')
              Expanded(
                child: TextButton.icon(
                  onPressed: _busy ? null : () => _setStatus('DECLINED'),
                  icon: const Icon(Icons.thumb_down_alt_outlined, color: AppColors.error),
                  label: const Text('Declined', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
                ),
              ),
            if (quote.status == 'DECLINED' || quote.status == 'ACCEPTED')
              Expanded(
                child: TextButton.icon(
                  onPressed: _busy ? null : () => _setStatus('SENT'),
                  icon: const Icon(Icons.undo, color: AppColors.textSecondary),
                  label: const Text('Reopen', style: TextStyle(color: AppColors.textSecondary)),
                ),
              ),
          ],
        ),
      ],
    ];
  }
}
