import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../models/product_model.dart';

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ProductRepository(apiClient);
});

class ProductRepository {
  final ApiClient _apiClient;

  ProductRepository(this._apiClient);

  Future<List<ProductModel>> getProducts({String? search}) async {
    final queryParams = <String, dynamic>{};
    if (search != null && search.trim().isNotEmpty) {
      queryParams['search'] = search.trim();
    }

    final response = await _apiClient.get(
      '/api/products',
      queryParameters: queryParams,
    );

    if (response['success'] == true && response['data'] is List) {
      return (response['data'] as List)
          .map((item) => ProductModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<ProductModel> createProduct({
    required String name,
    required double unitPrice,
    String? itemCode,
    String taxType = 'D-Non VAT',
  }) async {
    final body = {
      'name': name.trim(),
      'unit_price': unitPrice,
      'item_code': ?itemCode,
      'tax_type': taxType,
    };

    final response = await _apiClient.post('/api/products', data: body);
    if (response['success'] == true && response['data'] != null) {
      return ProductModel.fromJson(response['data'] as Map<String, dynamic>);
    }
    throw Exception('Failed to save product');
  }
}
