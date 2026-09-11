class ProductModel {
  final String id;
  final String? businessId;
  final String? itemCode;
  final String name;
  final double unitPrice;
  final String taxType;

  const ProductModel({
    required this.id,
    this.businessId,
    this.itemCode,
    required this.name,
    required this.unitPrice,
    this.taxType = 'D-Non VAT',
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id']?.toString() ?? '',
      businessId: json['business_id']?.toString(),
      itemCode: json['item_code']?.toString(),
      name: json['name'] ?? '',
      unitPrice: double.tryParse(json['unit_price']?.toString() ?? '0') ?? 0.0,
      taxType: json['tax_type']?.toString() ?? 'D-Non VAT',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'unit_price': unitPrice,
      'item_code': ?itemCode,
      'tax_type': taxType,
    };
  }
}
