class QuotationItemModel {
  final String? id;
  final String productName;
  final String? description;
  final double quantity;
  final double unitPrice;
  final double totalPrice;

  const QuotationItemModel({
    this.id,
    required this.productName,
    this.description,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
  });

  factory QuotationItemModel.fromJson(Map<String, dynamic> json) {
    return QuotationItemModel(
      id: json['id']?.toString(),
      productName: json['product_name'] ?? '',
      description: json['description']?.toString(),
      quantity: double.tryParse(json['quantity']?.toString() ?? '1') ?? 1.0,
      unitPrice: double.tryParse(json['unit_price']?.toString() ?? '0') ?? 0.0,
      totalPrice: double.tryParse(json['total_price']?.toString() ?? '0') ?? 0.0,
    );
  }
}

class QuotationModel {
  final String id;
  final String quoteNumber;
  final String customerName;
  final String? customerPhone;
  final String? customerEmail;
  final String status;
  final double subtotal;
  final double tax;
  final double totalAmount;
  final String quoteDate;
  final String dueDate;
  final String? terms;
  final String? invoiceId;
  final String? invoiceNumber;
  final String currency;
  final int itemCount;
  final List<QuotationItemModel> items;

  const QuotationModel({
    required this.id,
    required this.quoteNumber,
    required this.customerName,
    this.customerPhone,
    this.customerEmail,
    required this.status,
    required this.subtotal,
    required this.tax,
    required this.totalAmount,
    required this.quoteDate,
    required this.dueDate,
    this.terms,
    this.invoiceId,
    this.invoiceNumber,
    this.currency = 'KES',
    this.itemCount = 0,
    this.items = const [],
  });

  bool get canConvert => status != 'INVOICED' && status != 'DECLINED';

  factory QuotationModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final items = rawItems is List
        ? rawItems.map((i) => QuotationItemModel.fromJson(Map<String, dynamic>.from(i as Map))).toList()
        : <QuotationItemModel>[];

    return QuotationModel(
      id: json['id']?.toString() ?? '',
      quoteNumber: json['quote_number'] ?? '',
      customerName: json['customer_name'] ?? '',
      customerPhone: json['customer_phone']?.toString(),
      customerEmail: json['customer_email']?.toString(),
      status: json['status'] ?? 'SENT',
      subtotal: double.tryParse(json['subtotal']?.toString() ?? '0') ?? 0.0,
      tax: double.tryParse(json['tax']?.toString() ?? '0') ?? 0.0,
      totalAmount: double.tryParse(json['total_amount']?.toString() ?? '0') ?? 0.0,
      quoteDate: json['quote_date']?.toString() ?? '',
      dueDate: json['due_date']?.toString() ?? '',
      terms: json['terms']?.toString(),
      invoiceId: json['invoice_id']?.toString(),
      invoiceNumber: json['invoice_number']?.toString(),
      currency: json['currency'] ?? 'KES',
      itemCount: int.tryParse(json['item_count']?.toString() ?? '') ?? items.length,
      items: items,
    );
  }
}
