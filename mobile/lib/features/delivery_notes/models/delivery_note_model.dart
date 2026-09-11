class DeliveryNoteItemModel {
  final String? id;
  final String? deliveryNoteId;
  final String? invoiceItemId;
  final String productName;
  final double orderedQuantity;
  final double deliveredQuantity;

  const DeliveryNoteItemModel({
    this.id,
    this.deliveryNoteId,
    this.invoiceItemId,
    required this.productName,
    required this.orderedQuantity,
    required this.deliveredQuantity,
  });

  factory DeliveryNoteItemModel.fromJson(Map<String, dynamic> json) {
    return DeliveryNoteItemModel(
      id: json['id']?.toString(),
      deliveryNoteId: json['delivery_note_id']?.toString(),
      invoiceItemId: json['invoice_item_id']?.toString(),
      productName: json['product_name'] ?? '',
      orderedQuantity:
          double.tryParse(json['ordered_quantity']?.toString() ?? '0') ?? 0.0,
      deliveredQuantity:
          double.tryParse(json['delivered_quantity']?.toString() ?? '0') ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (deliveryNoteId != null) 'delivery_note_id': deliveryNoteId,
      if (invoiceItemId != null) 'invoice_item_id': invoiceItemId,
      'product_name': productName,
      'ordered_quantity': orderedQuantity,
      'delivered_quantity': deliveredQuantity,
    };
  }

  DeliveryNoteItemModel copyWith({
    String? id,
    String? deliveryNoteId,
    String? invoiceItemId,
    String? productName,
    double? orderedQuantity,
    double? deliveredQuantity,
  }) {
    return DeliveryNoteItemModel(
      id: id ?? this.id,
      deliveryNoteId: deliveryNoteId ?? this.deliveryNoteId,
      invoiceItemId: invoiceItemId ?? this.invoiceItemId,
      productName: productName ?? this.productName,
      orderedQuantity: orderedQuantity ?? this.orderedQuantity,
      deliveredQuantity: deliveredQuantity ?? this.deliveredQuantity,
    );
  }
}

class DeliveryNoteModel {
  final String id;
  final String invoiceId;
  final String businessId;
  final String noteNumber;
  final String status;
  final String? recipientName;
  final String? recipientSignatureUrl;
  final String? notes;
  final String? dispatchedAt;
  final String? deliveredAt;
  final String? createdAt;
  final String? updatedAt;
  final String? invoiceNumber;
  final String? customerName;
  final String? customerPhone;
  final String? businessName;
  final int itemCount;
  final List<DeliveryNoteItemModel> items;

  const DeliveryNoteModel({
    required this.id,
    required this.invoiceId,
    required this.businessId,
    required this.noteNumber,
    required this.status,
    this.recipientName,
    this.recipientSignatureUrl,
    this.notes,
    this.dispatchedAt,
    this.deliveredAt,
    this.createdAt,
    this.updatedAt,
    this.invoiceNumber,
    this.customerName,
    this.customerPhone,
    this.businessName,
    this.itemCount = 0,
    this.items = const [],
  });

  factory DeliveryNoteModel.fromJson(Map<String, dynamic> json) {
    var rawItems = json['items'];
    List<DeliveryNoteItemModel> parsedItems = [];
    if (rawItems is List) {
      parsedItems = rawItems
          .map((i) => DeliveryNoteItemModel.fromJson(i as Map<String, dynamic>))
          .toList();
    }

    return DeliveryNoteModel(
      id: json['id']?.toString() ?? '',
      invoiceId: json['invoice_id']?.toString() ?? '',
      businessId: json['business_id']?.toString() ?? '',
      noteNumber: json['note_number'] ?? '',
      status: json['status'] ?? 'PENDING',
      recipientName: json['recipient_name']?.toString(),
      recipientSignatureUrl: json['recipient_signature_url']?.toString(),
      notes: json['notes']?.toString(),
      dispatchedAt: json['dispatched_at']?.toString(),
      deliveredAt: json['delivered_at']?.toString(),
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
      invoiceNumber: json['invoice_number']?.toString(),
      customerName: json['customer_name']?.toString(),
      customerPhone: json['customer_phone']?.toString(),
      businessName: json['business_name']?.toString(),
      itemCount: int.tryParse(json['item_count']?.toString() ?? '0') ?? parsedItems.length,
      items: parsedItems,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'invoice_id': invoiceId,
      'business_id': businessId,
      'note_number': noteNumber,
      'status': status,
      'recipient_name': recipientName,
      'recipient_signature_url': recipientSignatureUrl,
      'notes': notes,
      'items': items.map((i) => i.toJson()).toList(),
    };
  }
}
