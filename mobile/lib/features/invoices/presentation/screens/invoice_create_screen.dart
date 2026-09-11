import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../data/invoice_repository.dart';
import '../../models/invoice_model.dart';
import '../../services/invoice_pdf_service.dart';
import 'invoice_detail_screen.dart';
import '../../../products/models/product_model.dart';
import '../../../products/presentation/controllers/product_providers.dart';
import '../../../copilot/presentation/screens/copilot_sheet.dart';
import '../../../copilot/services/screen_context_service.dart';

class _LineItemInput {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController descController = TextEditingController();
  final TextEditingController qtyController = TextEditingController(text: '1');
  final TextEditingController priceController = TextEditingController(text: '0');

  double get quantity => double.tryParse(qtyController.text) ?? 1.0;
  double get unitPrice => double.tryParse(priceController.text) ?? 0.0;
  double get total => quantity * unitPrice;

  void dispose() {
    nameController.dispose();
    descController.dispose();
    qtyController.dispose();
    priceController.dispose();
  }
}

class InvoiceCreateScreen extends ConsumerStatefulWidget {
  const InvoiceCreateScreen({super.key});

  @override
  ConsumerState<InvoiceCreateScreen> createState() => _InvoiceCreateScreenState();
}

class _InvoiceCreateScreenState extends ConsumerState<InvoiceCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _customerNameCtrl = TextEditingController();
  final _customerPhoneCtrl = TextEditingController();
  final _customerEmailCtrl = TextEditingController();
  final _customerPinCtrl = TextEditingController();
  final _notesCtrl = TextEditingController(text: 'Account are due on demand. Selisco Ltd Orthopaedic & Surgical.');
  final _taxCtrl = TextEditingController(text: '0');

  DateTime _dueDate = DateTime.now().add(const Duration(days: 30));
  bool _isSubmitting = false;

  final List<_LineItemInput> _items = [];

  @override
  void initState() {
    super.initState();
    // Add default initial line item
    _addLineItem();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(screenContextProvider.notifier).updateScreen(
        route: '/invoices/create',
        screenName: 'Create Invoice',
        customNote: 'User is drafting a new invoice. Form captures customer information and surgical line items.',
      );
    });
  }

  void _addLineItem() {
    setState(() {
      final item = _LineItemInput();
      item.qtyController.addListener(_recalculate);
      item.priceController.addListener(_recalculate);
      _items.add(item);
    });
  }

  void _removeLineItem(int index) {
    if (_items.length <= 1) return;
    setState(() {
      final item = _items.removeAt(index);
      item.dispose();
    });
  }

  void _recalculate() {
    setState(() {});
  }

  double get _subtotal => _items.fold(0.0, (sum, it) => sum + it.total);
  double get _tax => double.tryParse(_taxCtrl.text) ?? 0.0;
  double get _grandTotal => _subtotal + _tax;

  @override
  void dispose() {
    ref.read(screenContextProvider.notifier).updateScreen(
      route: '/invoices',
      screenName: 'Invoices',
      formData: null,
      customNote: 'Invoices list dashboard.',
    );
    _customerNameCtrl.dispose();
    _customerPhoneCtrl.dispose();
    _customerEmailCtrl.dispose();
    _customerPinCtrl.dispose();
    _notesCtrl.dispose();
    _taxCtrl.dispose();
    for (var item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  /// Modal BottomSheet to quickly select an item from saved catalog items
  void _showCatalogPicker({int? targetIndex}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        return _CatalogPickerBottomSheet(
          onProductSelected: (ProductModel product) {
            Navigator.pop(modalCtx);
            _promptQuantityAndApply(product, targetIndex: targetIndex);
          },
        );
      },
    );
  }

  /// Dialog to enter quantity AND customize price right after picking item
  void _promptQuantityAndApply(ProductModel product, {int? targetIndex}) {
    final qtyCtrl = TextEditingController(text: '1');
    final priceCtrl = TextEditingController(text: product.unitPrice.toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (dlgCtx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            final double q = double.tryParse(qtyCtrl.text.trim()) ?? 1.0;
            final double p = double.tryParse(priceCtrl.text.trim()) ?? product.unitPrice;
            final double computedTotal = q * p;

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                product.name,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (product.itemCode != null && product.itemCode!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          'Code: ${product.itemCode}',
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ),
                    // Quantity Input
                    TextField(
                      controller: qtyCtrl,
                      autofocus: true,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Quantity',
                        hintText: 'e.g. 1, 2, 6, 8',
                        prefixIcon: Icon(Icons.pin_outlined),
                      ),
                      onChanged: (_) => setDlgState(() {}),
                    ),
                    const SizedBox(height: 12),
                    // Editable Unit Price Input
                    TextField(
                      controller: priceCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Unit Price (KSh) - Customizable',
                        hintText: 'e.g. 15000',
                        prefixIcon: Icon(Icons.payments_outlined),
                      ),
                      onChanged: (_) => setDlgState(() {}),
                    ),
                    const SizedBox(height: 14),
                    // Live Computed Total Preview
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Line Total:', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                          Text(
                            Formatters.currency(computedTotal),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dlgCtx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final qty = double.tryParse(qtyCtrl.text.trim()) ?? 1.0;
                    final price = double.tryParse(priceCtrl.text.trim()) ?? product.unitPrice;
                    Navigator.pop(dlgCtx);

                    setState(() {
                      _LineItemInput item;
                      if (targetIndex != null && targetIndex < _items.length) {
                        item = _items[targetIndex];
                      } else {
                        // Check if current last item is blank, reuse it
                        if (_items.isNotEmpty && _items.last.nameController.text.trim().isEmpty) {
                          item = _items.last;
                        } else {
                          item = _LineItemInput();
                          item.qtyController.addListener(_recalculate);
                          item.priceController.addListener(_recalculate);
                          _items.add(item);
                        }
                      }

                      item.nameController.text = product.name;
                      if (product.itemCode != null && product.itemCode!.isNotEmpty) {
                        item.descController.text = 'Code: ${product.itemCode}';
                      }
                      item.priceController.text = price.toStringAsFixed(0);
                      item.qtyController.text = qty % 1 == 0 ? qty.toInt().toString() : qty.toString();
                    });
                  },
                  child: const Text('Add to Invoice'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _submitInvoice() async {
    if (!_formKey.currentState!.validate()) return;

    for (var item in _items) {
      if (item.nameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a product name for all items.')),
        );
        return;
      }
    }

    setState(() => _isSubmitting = true);

    try {
      final repository = ref.read(invoiceRepositoryProvider);
      final itemsPayload = _items.map((it) {
        return {
          'product_name': it.nameController.text.trim(),
          'description': it.descController.text.trim(),
          'quantity': it.quantity,
          'unit_price': it.unitPrice,
        };
      }).toList();

      final pinText = _customerPinCtrl.text.trim();

      final createdInvoice = await repository.createInvoice(
        customerName: _customerNameCtrl.text.trim(),
        customerPhone: _customerPhoneCtrl.text.trim(),
        customerEmail: _customerEmailCtrl.text.trim(),
        customerPin: pinText.isEmpty ? null : pinText,
        items: itemsPayload,
        tax: _tax,
        dueDate: DateFormat('yyyy-MM-dd').format(_dueDate),
        notes: _notesCtrl.text.trim(),
      );

      if (mounted) {
        await _showInvoiceCreatedSuccessModal(createdInvoice);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text('Failed to create invoice: ${e.toString()}'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  /// Displays immediate post-creation success modal with direct share capability
  Future<void> _showInvoiceCreatedSuccessModal(InvoiceModel invoice) async {
    bool isSharing = false;

    await showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
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
                  // Success badge icon
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.success,
                      size: 42,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Invoice Created Successfully!',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${invoice.invoiceNumber} • ${invoice.customerName}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    Formatters.currency(invoice.totalAmount, currencyCode: invoice.currency),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Primary Action: Share Direct from App
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: isSharing
                          ? null
                          : () async {
                              setModalState(() => isSharing = true);
                              try {
                                await InvoicePdfService.shareInvoicePdf(invoice);
                              } catch (e) {
                                if (modalCtx.mounted) {
                                  ScaffoldMessenger.of(modalCtx).showSnackBar(
                                    SnackBar(
                                      content: Text('Failed to share: $e'),
                                      backgroundColor: AppColors.error,
                                    ),
                                  );
                                }
                              } finally {
                                if (modalCtx.mounted) {
                                  setModalState(() => isSharing = false);
                                }
                              }
                            },
                      icon: isSharing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.share_rounded, size: 22),
                      label: Text(
                        isSharing ? 'Preparing PDF...' : 'Share Invoice (WhatsApp, Email...)',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669), // Emerald WhatsApp green
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Secondary Action: View Invoice Details
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(modalCtx); // Close modal
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => InvoiceDetailScreen(invoiceId: invoice.id),
                          ),
                        );
                      },
                      icon: const Icon(Icons.visibility_outlined, size: 20),
                      label: const Text('View Invoice Details', style: TextStyle(fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Tertiary: Done / Return to list
                  TextButton(
                    onPressed: () {
                      Navigator.pop(modalCtx);
                      Navigator.pop(context, true); // return to invoice list
                    },
                    child: const Text('Done', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Invoice'),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome, color: AppColors.primary),
            tooltip: 'Copilot Assistant',
            onPressed: () {
              ref.read(screenContextProvider.notifier).updateFormData({
                'customer_name': _customerNameCtrl.text,
                'customer_phone': _customerPhoneCtrl.text,
                'customer_email': _customerEmailCtrl.text,
                'customer_pin': _customerPinCtrl.text,
                'items_count': _items.length,
                'subtotal': _subtotal,
              });
              CopilotSheet.show(context);
            },
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Customer Details Card
            _buildSectionCard(
              title: 'Customer / Hospital Information',
              icon: Icons.local_hospital_outlined,
              children: [
                TextFormField(
                  controller: _customerNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'M/s / Hospital / Customer Name *',
                    hintText: 'e.g. Living Room International Hospital',
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                // Optional Company PIN field
                TextFormField(
                  controller: _customerPinCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Company PIN / KRA PIN (Optional)',
                    hintText: 'e.g. P051234567Z',
                    prefixIcon: Icon(Icons.badge_outlined, size: 20),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _customerPhoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number',
                          hintText: '0787371118',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _customerEmailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email Address',
                          hintText: 'hospital@selisco.com',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Due Date Picker
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _dueDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setState(() => _dueDate = picked);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.white,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Payment Due Date',
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              DateFormat('EEEE, dd/MM/yyyy').format(_dueDate),
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                          ],
                        ),
                        const Icon(Icons.calendar_today, size: 20, color: AppColors.primary),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Line Items Card
            _buildSectionCard(
              title: 'Particulars / Items',
              icon: Icons.list_alt,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () => _showCatalogPicker(),
                    icon: const Icon(Icons.inventory_2, size: 16),
                    label: const Text('Pick Item'),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
                    tooltip: 'Add Blank Row',
                    onPressed: _addLineItem,
                  ),
                ],
              ),
              children: [
                ..._items.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final item = entry.value;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Item #${idx + 1}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const Spacer(),
                            // Quick button to pick catalog item for this row
                            TextButton.icon(
                              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2)),
                              onPressed: () => _showCatalogPicker(targetIndex: idx),
                              icon: const Icon(Icons.search, size: 14),
                              label: const Text('Catalog', style: TextStyle(fontSize: 11)),
                            ),
                            if (_items.length > 1)
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                                onPressed: () => _removeLineItem(idx),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: item.nameController,
                          decoration: const InputDecoration(
                            labelText: 'Particulars / Item Name *',
                            hintText: 'e.g. Straight T-Plate 20x12 holes',
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: item.descController,
                          decoration: const InputDecoration(
                            labelText: 'Specifications / Code (Optional)',
                            hintText: 'e.g. KE2BLXAVX00001',
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: item.qtyController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(labelText: 'Qty'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: item.priceController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(labelText: '@ Unit Price (KSh)'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text(
                                    'Shs.',
                                    style: TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    Formatters.currency(item.total),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),

            const SizedBox(height: 16),

            // Financial Summary Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Subtotal', style: TextStyle(color: AppColors.textSecondary)),
                      Text(Formatters.currency(_subtotal), style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Tax / VAT (KSh)', style: TextStyle(color: AppColors.textSecondary)),
                      SizedBox(
                        width: 100,
                        child: TextFormField(
                          controller: _taxCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          textAlign: TextAlign.right,
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'TOTAL (Shs.)',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      Text(
                        Formatters.currency(_grandTotal),
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Notes / Terms
            TextFormField(
              controller: _notesCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Notes & Terms',
                hintText: 'ACCOUNT ARE DUE ON DEMAND',
              ),
            ),

            const SizedBox(height: 28),

            // Submit Button
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitInvoice,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Save & Issue Receipt / Invoice', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 20),
            const Center(
              child: Text(
                'Powered by Xuremi • +254715329007',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    Widget? trailing,
    required List<Widget> children,
  }) {
    return Container(
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
              Row(
                children: [
                  Icon(icon, size: 20, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

/// Quick BottomSheet to search & click an item from catalog
class _CatalogPickerBottomSheet extends ConsumerStatefulWidget {
  final ValueChanged<ProductModel> onProductSelected;

  const _CatalogPickerBottomSheet({required this.onProductSelected});

  @override
  ConsumerState<_CatalogPickerBottomSheet> createState() => _CatalogPickerBottomSheetState();
}

class _CatalogPickerBottomSheetState extends ConsumerState<_CatalogPickerBottomSheet> {
  final TextEditingController _filterCtrl = TextEditingController();

  @override
  void dispose() {
    _filterCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsListProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.inventory_2, color: AppColors.primary),
                    const SizedBox(width: 8),
                    const Text(
                      'Select Orthopaedic / Surgical Item',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  controller: _filterCtrl,
                  autofocus: false,
                  decoration: InputDecoration(
                    hintText: 'Search items (e.g. T-plate, screw, mandibular...)',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    filled: true,
                    fillColor: AppColors.background,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (val) {
                    ref.read(productSearchProvider.notifier).setSearch(val);
                  },
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: productsAsync.when(
                  data: (products) {
                    if (products.isEmpty) {
                      return const Center(child: Text('No items match your search'));
                    }
                    return ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.all(12),
                      itemCount: products.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final prod = products[index];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          leading: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.medical_services_outlined, size: 18, color: AppColors.primary),
                          ),
                          title: Text(
                            prod.name,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          subtitle: prod.itemCode != null && prod.itemCode!.isNotEmpty
                              ? Text(prod.itemCode!, style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))
                              : null,
                          trailing: Text(
                            Formatters.currency(prod.unitPrice),
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 13),
                          ),
                          onTap: () => widget.onProductSelected(prod),
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                  error: (err, _) => Center(child: Text('Error loading catalog: $err')),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
