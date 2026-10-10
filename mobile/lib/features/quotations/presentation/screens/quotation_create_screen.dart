import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_exceptions.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/catalog_picker_sheet.dart';
import '../../../products/models/product_model.dart';
import '../../../copilot/services/screen_context_service.dart';
import '../../data/quotation_repository.dart';
import '../../models/quotation_model.dart';
import '../../services/quotation_pdf_service.dart';
import 'quotation_detail_screen.dart';

const String kDefaultQuotationTerms =
    'Payment is due within 14 days.\nPlease make cheques payable to SELISCO LTD.';

class _QuoteLine {
  final TextEditingController name = TextEditingController();
  final TextEditingController desc = TextEditingController();
  final TextEditingController qty = TextEditingController(text: '1');
  final TextEditingController price = TextEditingController(text: '0');

  double get quantity => double.tryParse(qty.text.trim()) ?? 0;
  double get unitPrice => double.tryParse(price.text.trim()) ?? 0;
  double get total => quantity * unitPrice;

  void dispose() {
    name.dispose();
    desc.dispose();
    qty.dispose();
    price.dispose();
  }
}

class QuotationCreateScreen extends ConsumerStatefulWidget {
  const QuotationCreateScreen({super.key});

  @override
  ConsumerState<QuotationCreateScreen> createState() => _QuotationCreateScreenState();
}

class _QuotationCreateScreenState extends ConsumerState<QuotationCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _customerCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _taxCtrl = TextEditingController(text: '0');
  final _termsCtrl = TextEditingController(text: kDefaultQuotationTerms);
  DateTime _dueDate = DateTime.now().add(const Duration(days: 14));
  bool _isSubmitting = false;
  final List<_QuoteLine> _lines = [];

  @override
  void initState() {
    super.initState();
    _addLine();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(screenContextProvider.notifier).updateScreen(
            route: '/quotations/create',
            screenName: 'Create Quotation',
            customNote: 'User is preparing a price quotation for a customer.',
          );
    });
  }

  @override
  void dispose() {
    _customerCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _taxCtrl.dispose();
    _termsCtrl.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  void _addLine() {
    final line = _QuoteLine();
    line.qty.addListener(_refresh);
    line.price.addListener(_refresh);
    setState(() => _lines.add(line));
  }

  void _removeLine(int index) {
    if (_lines.length <= 1) return;
    setState(() => _lines.removeAt(index).dispose());
  }

  void _refresh() => setState(() {});

  double get _subtotal => _lines.fold(0.0, (sum, l) => sum + l.total);
  double get _tax => double.tryParse(_taxCtrl.text.trim()) ?? 0;
  double get _total => _subtotal + _tax;

  void _pickFromCatalog({int? targetIndex}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => CatalogPickerSheet(
        onProductSelected: (ProductModel product) {
          Navigator.pop(sheetCtx);
          _applyProduct(product, targetIndex: targetIndex);
        },
      ),
    );
  }

  void _applyProduct(ProductModel product, {int? targetIndex}) {
    setState(() {
      _QuoteLine line;
      if (targetIndex != null && targetIndex < _lines.length) {
        line = _lines[targetIndex];
      } else if (_lines.isNotEmpty && _lines.last.name.text.trim().isEmpty) {
        line = _lines.last;
      } else {
        line = _QuoteLine();
        line.qty.addListener(_refresh);
        line.price.addListener(_refresh);
        _lines.add(line);
      }
      line.name.text = product.name;
      line.desc.text = (product.itemCode != null && product.itemCode!.isNotEmpty) ? 'Code: ${product.itemCode}' : '';
      line.price.text = product.unitPrice.toStringAsFixed(0);
    });
  }

  String _errorText(Object e) => e is ApiException ? e.message : e.toString().replaceAll('Exception: ', '');

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    for (final l in _lines) {
      if (l.name.text.trim().isEmpty || l.quantity <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Every item needs a description and a quantity above 0.')),
        );
        return;
      }
    }

    setState(() => _isSubmitting = true);
    try {
      final quote = await ref.read(quotationRepositoryProvider).createQuotation(
            customerName: _customerCtrl.text.trim(),
            customerPhone: _phoneCtrl.text.trim(),
            customerEmail: _emailCtrl.text.trim(),
            items: _lines
                .map((l) => {
                      'product_name': l.name.text.trim(),
                      'description': l.desc.text.trim(),
                      'quantity': l.quantity,
                      'unit_price': l.unitPrice,
                    })
                .toList(),
            tax: _tax,
            dueDate: DateFormat('yyyy-MM-dd').format(_dueDate),
            terms: _termsCtrl.text.trim(),
          );
      if (mounted) await _showCreatedSheet(quote);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppColors.error, content: Text('Failed to create quotation: ${_errorText(e)}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _showCreatedSheet(QuotationModel quote) async {
    bool sharing = false;
    await showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 56),
              const SizedBox(height: 12),
              const Text('Quotation Created', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(
                '${quote.quoteNumber} • ${quote.customerName}',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 4),
              Text(
                Formatters.currency(quote.totalAmount, currencyCode: quote.currency),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: sharing
                      ? null
                      : () async {
                          setSheetState(() => sharing = true);
                          try {
                            await QuotationPdfService.shareQuotationPdf(quote);
                          } catch (e) {
                            if (sheetCtx.mounted) {
                              ScaffoldMessenger.of(sheetCtx).showSnackBar(
                                SnackBar(content: Text('Failed to share: $e'), backgroundColor: AppColors.error),
                              );
                            }
                          } finally {
                            if (sheetCtx.mounted) setSheetState(() => sharing = false);
                          }
                        },
                  icon: const Icon(Icons.share_rounded),
                  label: Text(
                    sharing ? 'Preparing PDF...' : 'Share Quotation (WhatsApp, Email...)',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetCtx);
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => QuotationDetailScreen(quotationId: quote.id)),
                    );
                  },
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('View Quotation'),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(sheetCtx);
                  Navigator.pop(context, true);
                },
                child: const Text('Done', style: TextStyle(color: AppColors.textSecondary)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Quotation')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _section(
              title: 'To (Customer / Hospital)',
              icon: Icons.local_hospital_outlined,
              children: [
                TextFormField(
                  controller: _customerCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Customer / Hospital Name *',
                    hintText: 'e.g. Nairobi West Hospital',
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(labelText: 'Phone'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(labelText: 'Email'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _dueDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) setState(() => _dueDate = picked);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.white,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Due Date', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              const SizedBox(height: 2),
                              Text(
                                DateFormat('EEEE, dd/MM/yyyy').format(_dueDate),
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.calendar_today, size: 20, color: AppColors.primary),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _section(
              title: 'Items',
              icon: Icons.list_alt,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () => _pickFromCatalog(),
                    icon: const Icon(Icons.inventory_2, size: 16),
                    label: const Text('Pick Item'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
                    tooltip: 'Add blank row',
                    onPressed: _addLine,
                  ),
                ],
              ),
              children: [
                for (int i = 0; i < _lines.length; i++) _buildLine(i),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  _totalRow('Subtotal', Formatters.currency(_subtotal)),
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
                      const Text('TOTAL', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Text(
                        Formatters.currency(_total),
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _termsCtrl,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Terms and Conditions'),
            ),
            const SizedBox(height: 28),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Save Quotation', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildLine(int index) {
    final line = _lines[index];
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
                'Item #${index + 1}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
              ),
              const Spacer(),
              TextButton.icon(
                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2)),
                onPressed: () => _pickFromCatalog(targetIndex: index),
                icon: const Icon(Icons.search, size: 14),
                label: const Text('Catalog', style: TextStyle(fontSize: 11)),
              ),
              if (_lines.length > 1)
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                  onPressed: () => _removeLine(index),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: line.name,
            decoration: const InputDecoration(labelText: 'Description *', hintText: 'e.g. Straight T-Plate 20x12 holes'),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: line.desc,
            decoration: const InputDecoration(labelText: 'Specification / Code (Optional)'),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: line.qty,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Qty'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: line.price,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Unit Price (KSh)'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Amount', style: TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.bold)),
                    Text(
                      Formatters.currency(line.total),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _totalRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _section({required String title, required IconData icon, Widget? trailing, required List<Widget> children}) {
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
            children: [
              Icon(icon, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
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
