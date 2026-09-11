import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../delivery_notes/presentation/screens/delivery_note_detail_screen.dart';
import '../../data/invoice_repository.dart';
import '../../models/invoice_model.dart';
import '../controllers/invoice_providers.dart';
import '../../services/invoice_pdf_service.dart';
import '../../../copilot/presentation/screens/copilot_sheet.dart';
import '../../../copilot/services/screen_context_service.dart';

class InvoiceDetailScreen extends ConsumerStatefulWidget {
  final String invoiceId;

  const InvoiceDetailScreen({super.key, required this.invoiceId});

  @override
  ConsumerState<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends ConsumerState<InvoiceDetailScreen> {
  bool _isConverting = false;

  Future<void> _convertToDeliveryNote(InvoiceModel invoice) async {
    setState(() => _isConverting = true);
    try {
      final repository = ref.read(invoiceRepositoryProvider);
      final result = await repository.convertToDeliveryNote(invoice.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.success,
            content: Text('Delivery Note created successfully!'),
          ),
        );

        final deliveryNoteId = result['id']?.toString();
        if (deliveryNoteId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DeliveryNoteDetailScreen(deliveryNoteId: deliveryNoteId),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text('Conversion failed: ${e.toString()}'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isConverting = false);
    }
  }

  void _showQrVerificationModal(InvoiceModel invoice) {
    final verifyUrl =
        '${ApiConstants.verificationBaseUrl}/${invoice.id}?token=${invoice.verificationToken}';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Cryptographic Verification QR',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Scan with any mobile camera to view the live verified record.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              // QR Code container
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: QrImageView(
                  data: verifyUrl,
                  version: QrVersions.auto,
                  size: 200.0,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: AppColors.primaryDark,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: SelectableText(
                  verifyUrl,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: AppColors.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final invoiceAsync = ref.watch(invoiceDetailProvider(widget.invoiceId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoice Details'),
        actions: [
          invoiceAsync.when(
            data: (invoice) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.auto_awesome, color: AppColors.primary),
                  tooltip: 'Copilot Assistant',
                  onPressed: () {
                    ref.read(screenContextProvider.notifier).updateScreen(
                      route: '/invoices/detail',
                      screenName: 'Invoice Details',
                      activeRecord: {
                        'id': invoice.id,
                        'invoice_number': invoice.invoiceNumber,
                        'customer_name': invoice.customerName,
                        'status': invoice.status,
                        'total_amount': invoice.totalAmount,
                      },
                      customNote: 'Inspecting invoice ${invoice.invoiceNumber} for ${invoice.customerName} (Total: KES ${invoice.totalAmount}).',
                    );
                    CopilotSheet.show(context);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.share_outlined),
                  tooltip: 'Share Invoice (PDF)',
                  onPressed: () => InvoicePdfService.shareInvoicePdf(invoice),
                ),
                IconButton(
                  icon: const Icon(Icons.qr_code_2),
                  tooltip: 'Verification QR',
                  onPressed: () => _showQrVerificationModal(invoice),
                ),
              ],
            ),
            loading: () => const SizedBox.shrink(),
            error: (err, stack) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: invoiceAsync.when(
        data: (invoice) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Header Status Card
              Container(
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
                        Text(
                          invoice.invoiceNumber,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        StatusBadge(status: invoice.status),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      invoice.customerName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (invoice.customerPhone != null)
                      Text(invoice.customerPhone!, style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
                    if (invoice.customerEmail != null)
                      Text(invoice.customerEmail!, style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
                    if (invoice.customerPin != null && invoice.customerPin!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.badge_outlined, size: 14, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Text(
                              'PIN: ${invoice.customerPin!}',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
                            ),
                          ],
                        ),
                      ),

                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Issued Date', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                            Text(Formatters.date(invoice.issuedDate), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('Due Date', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                            Text(Formatters.date(invoice.dueDate), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Itemized Table
              Container(
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
                      child: Text(
                        'Items & Services',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    ...invoice.items.map((item) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.productName,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                  ),
                                  if (item.description != null && item.description!.isNotEmpty)
                                    Text(
                                      item.description!,
                                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                    ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${item.quantity.toStringAsFixed(0)} × ${Formatters.currency(item.unitPrice, currencyCode: invoice.currency)}',
                                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                Formatters.currency(item.totalPrice, currencyCode: invoice.currency),
                                textAlign: TextAlign.right,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const Divider(height: 1),
                    // Totals
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Subtotal', style: TextStyle(color: AppColors.textSecondary)),
                              Text(Formatters.currency(invoice.subtotal, currencyCode: invoice.currency)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Tax', style: TextStyle(color: AppColors.textSecondary)),
                              Text(Formatters.currency(invoice.tax, currencyCode: invoice.currency)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total Amount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              Text(
                                Formatters.currency(invoice.totalAmount, currencyCode: invoice.currency),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.primary),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Action Buttons
              // 1. Direct Share via Apps (WhatsApp, Email, etc.)
              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () => InvoicePdfService.shareInvoicePdf(invoice),
                  icon: const Icon(Icons.share_rounded),
                  label: const Text('Share Invoice via Apps (WhatsApp, Email...)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // 2. PDF Generation & Print
              SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () => InvoicePdfService.printOrShareInvoice(context, invoice),
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('View / Print A4 PDF Document'),
                ),
              ),

              const SizedBox(height: 12),

              // 2. 1-Click Convert to Delivery Note
              SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _isConverting ? null : () => _convertToDeliveryNote(invoice),
                  icon: _isConverting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.local_shipping_outlined),
                  label: Text(_isConverting ? 'Generating Delivery Note...' : '1-Click Convert to Delivery Note'),
                ),
              ),

              const SizedBox(height: 12),

              // 3. Mark as Paid / Status update
              if (invoice.status != 'PAID')
                SizedBox(
                  height: 48,
                  child: TextButton.icon(
                    onPressed: () async {
                      await ref.read(invoiceRepositoryProvider).updateInvoiceStatus(invoice.id, 'PAID');
                      ref.invalidate(invoiceDetailProvider(invoice.id));
                      ref.invalidate(invoicesListProvider);
                    },
                    icon: const Icon(Icons.check_circle_outline, color: AppColors.success),
                    label: const Text('Mark as Paid', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold)),
                  ),
                ),

              const SizedBox(height: 32),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }
}
