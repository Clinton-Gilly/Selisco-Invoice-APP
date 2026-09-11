class InvoiceItemModel {
  final String? id;
  final String? invoiceId;
  final String productName;
  final String? description;
  final double quantity;
  final double unitPrice;
  final double totalPrice;

  const InvoiceItemModel({
    this.id,
    this.invoiceId,
    required this.productName,
    this.description,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
  });

  factory InvoiceItemModel.fromJson(Map<String, dynamic> json) {
    return InvoiceItemModel(
      id: json['id']?.toString(),
      invoiceId: json['invoice_id']?.toString(),
      productName: json['product_name'] ?? '',
      description: json['description']?.toString(),
      quantity: double.tryParse(json['quantity']?.toString() ?? '1') ?? 1.0,
      unitPrice: double.tryParse(json['unit_price']?.toString() ?? '0') ?? 0.0,
      totalPrice: double.tryParse(json['total_price']?.toString() ?? '0') ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (invoiceId != null) 'invoice_id': invoiceId,
      'product_name': productName,
      if (description != null) 'description': description,
      'quantity': quantity,
      'unit_price': unitPrice,
      'total_price': totalPrice,
    };
  }

  InvoiceItemModel copyWith({
    String? id,
    String? invoiceId,
    String? productName,
    String? description,
    double? quantity,
    double? unitPrice,
    double? totalPrice,
  }) {
    return InvoiceItemModel(
      id: id ?? this.id,
      invoiceId: invoiceId ?? this.invoiceId,
      productName: productName ?? this.productName,
      description: description ?? this.description,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      totalPrice: totalPrice ?? this.totalPrice,
    );
  }
}

class InvoiceModel {
  final String id;
  final String businessId;
  final String invoiceNumber;
  final String customerName;
  final String? customerPhone;
  final String? customerEmail;
  final String? customerPin;
  final String status;
  final double subtotal;
  final double tax;
  final double totalAmount;
  final String verificationToken;
  final String issuedDate;
  final String dueDate;
  final String? notes;
  final String? createdAt;
  final String? updatedAt;
  final String currency;
  final String? businessName;
  final bool hasDeliveryNote;
  final List<InvoiceItemModel> items;

  const InvoiceModel({
    required this.id,
    required this.businessId,
    required this.invoiceNumber,
    required this.customerName,
    this.customerPhone,
    this.customerEmail,
    this.customerPin,
    required this.status,
    required this.subtotal,
    required this.tax,
    required this.totalAmount,
    required this.verificationToken,
    required this.issuedDate,
    required this.dueDate,
    this.notes,
    this.createdAt,
    this.updatedAt,
    this.currency = 'KES',
    this.businessName,
    this.hasDeliveryNote = false,
    this.items = const [],
  });

  factory InvoiceModel.fromJson(Map<String, dynamic> json) {
    var rawItems = json['items'];
    List<InvoiceItemModel> parsedItems = [];
    if (rawItems is List) {
      parsedItems = rawItems.map((i) => InvoiceItemModel.fromJson(i as Map<String, dynamic>)).toList();
    }

    return InvoiceModel(
      id: json['id']?.toString() ?? '',
      businessId: json['business_id']?.toString() ?? '',
      invoiceNumber: json['invoice_number'] ?? '',
      customerName: json['customer_name'] ?? '',
      customerPhone: json['customer_phone']?.toString(),
      customerEmail: json['customer_email']?.toString(),
      customerPin: json['customer_pin']?.toString(),
      status: json['status'] ?? 'ISSUED',
      subtotal: double.tryParse(json['subtotal']?.toString() ?? '0') ?? 0.0,
      tax: double.tryParse(json['tax']?.toString() ?? '0') ?? 0.0,
      totalAmount: double.tryParse(json['total_amount']?.toString() ?? '0') ?? 0.0,
      verificationToken: json['verification_token'] ?? '',
      issuedDate: json['issued_date']?.toString() ?? '',
      dueDate: json['due_date']?.toString() ?? '',
      notes: json['notes']?.toString(),
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
      currency: json['currency'] ?? 'KES',
      businessName: json['business_name']?.toString() ?? 'SELISCO LTD',
      hasDeliveryNote: json['has_delivery_note'] == true,
      items: parsedItems,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'business_id': businessId,
      'invoice_number': invoiceNumber,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'customer_email': customerEmail,
      'customer_pin': customerPin,
      'status': status,
      'subtotal': subtotal,
      'tax': tax,
      'total_amount': totalAmount,
      'verification_token': verificationToken,
      'issued_date': issuedDate,
      'due_date': dueDate,
      'notes': notes,
      'items': items.map((i) => i.toJson()).toList(),
    };
  }
}
