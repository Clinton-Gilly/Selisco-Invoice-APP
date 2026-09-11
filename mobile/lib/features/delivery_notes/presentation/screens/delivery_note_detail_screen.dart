import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../data/delivery_note_repository.dart';
import '../../models/delivery_note_model.dart';
import '../controllers/delivery_note_providers.dart';
import '../../services/delivery_note_pdf_service.dart';

class DeliveryNoteDetailScreen extends ConsumerStatefulWidget {
  final String deliveryNoteId;

  const DeliveryNoteDetailScreen({super.key, required this.deliveryNoteId});

  @override
  ConsumerState<DeliveryNoteDetailScreen> createState() => _DeliveryNoteDetailScreenState();
}

class _DeliveryNoteDetailScreenState extends ConsumerState<DeliveryNoteDetailScreen> {
  final Map<String, double> _deliveredQuantities = {};
  bool _isSaving = false;

  void _initItemQuantities(List<DeliveryNoteItemModel> items) {
    if (_deliveredQuantities.isEmpty) {
      for (var it in items) {
        if (it.id != null) {
          _deliveredQuantities[it.id!] = it.deliveredQuantity;
        }
      }
    }
  }

  Future<void> _updateStatus(String newStatus, DeliveryNoteModel note) async {
    setState(() => _isSaving = true);
    try {
      final repository = ref.read(deliveryNoteRepositoryProvider);
      await repository.updateDeliveryNote(
        note.id,
        status: newStatus,
      );

      ref.invalidate(deliveryNoteDetailProvider(note.id));
      ref.invalidate(deliveryNotesListProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.success,
            content: Text('Status updated to $newStatus'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text('Failed to update status: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _saveItemDeliveries(DeliveryNoteModel note) async {
    setState(() => _isSaving = true);
    try {
      final repository = ref.read(deliveryNoteRepositoryProvider);
      final updatedItems = note.items.map((it) {
        return it.copyWith(
          deliveredQuantity: _deliveredQuantities[it.id] ?? it.deliveredQuantity,
        );
      }).toList();

      await repository.updateDeliveryNote(
        note.id,
        items: updatedItems,
      );

      ref.invalidate(deliveryNoteDetailProvider(note.id));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.success,
            content: Text('Delivered quantities updated successfully!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text('Failed to update items: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final noteAsync = ref.watch(deliveryNoteDetailProvider(widget.deliveryNoteId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Delivery Note Details'),
        actions: [
          noteAsync.when(
            data: (note) => IconButton(
              icon: const Icon(Icons.share_outlined),
              tooltip: 'Share Delivery Note (PDF)',
              onPressed: () => DeliveryNotePdfService.shareDeliveryNotePdf(note),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: noteAsync.when(
        data: (note) {
          _initItemQuantities(note.items);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Header Card
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          note.noteNumber,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        StatusBadge(status: note.status, isDelivery: true),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Recipient: ${note.recipientName ?? note.customerName ?? 'Customer'}',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    if (note.invoiceNumber != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Attached Invoice: ${note.invoiceNumber}',
                        style: const TextStyle(fontSize: 12, color: AppColors.primary),
                      ),
                    ],
                    if (note.deliveredAt != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Delivered At: ${Formatters.date(note.deliveredAt)}',
                        style: const TextStyle(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Item Tracking Section: Ordered vs Delivered
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text(
                          'Item Fulfillment Tracking',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Ordered vs Delivered',
                          style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    ...note.items.map((item) {
                      final delivered = _deliveredQuantities[item.id] ?? item.deliveredQuantity;
                      final isFull = delivered >= item.orderedQuantity;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isFull ? AppColors.success.withValues(alpha: 0.3) : AppColors.border,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.productName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Ordered info
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Ordered', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                    Text(
                                      item.orderedQuantity.toStringAsFixed(0),
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                    ),
                                  ],
                                ),

                                // Delivered adjustment controls
                                Row(
                                  children: [
                                    IconButton(
                                      onPressed: delivered > 0
                                          ? () {
                                              setState(() {
                                                _deliveredQuantities[item.id!] = delivered - 1;
                                              });
                                            }
                                          : null,
                                      icon: const Icon(Icons.remove_circle_outline, size: 22),
                                      color: AppColors.textSecondary,
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: AppColors.border),
                                      ),
                                      child: Text(
                                        delivered.toStringAsFixed(0),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: isFull ? AppColors.success : AppColors.primary,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () {
                                        setState(() {
                                          _deliveredQuantities[item.id!] = delivered + 1;
                                        });
                                      },
                                      icon: const Icon(Icons.add_circle_outline, size: 22),
                                      color: AppColors.primary,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isSaving ? null : () => _saveItemDeliveries(note),
                        icon: const Icon(Icons.save_outlined, size: 18),
                        label: const Text('Save Quantity Updates'),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Status Tracking Actions
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
                    const Text(
                      'Update Delivery Status',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isSaving || note.status == 'IN_TRANSIT'
                                ? null
                                : () => _updateStatus('IN_TRANSIT', note),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.info,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            child: const Text('In Transit', style: TextStyle(fontSize: 12)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isSaving || note.status == 'DELIVERED'
                                ? null
                                : () => _updateStatus('DELIVERED', note),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            child: const Text('Delivered', style: TextStyle(fontSize: 12)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isSaving || note.status == 'REJECTED'
                                ? null
                                : () => _updateStatus('REJECTED', note),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.error,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            child: const Text('Rejected', style: TextStyle(fontSize: 12)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 1. Share via Apps (WhatsApp, Email, etc.)
              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () => DeliveryNotePdfService.shareDeliveryNotePdf(note),
                  icon: const Icon(Icons.share_rounded),
                  label: const Text('Share Delivery Note via Apps (WhatsApp, Email...)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // 2. Print A4 PDF
              SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () => DeliveryNotePdfService.printOrShareDeliveryNote(context, note),
                  icon: const Icon(Icons.print_outlined),
                  label: const Text('Print A4 Delivery Note with Sign-off Box'),
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
