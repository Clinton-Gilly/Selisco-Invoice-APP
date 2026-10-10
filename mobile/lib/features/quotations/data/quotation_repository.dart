import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/quotation_model.dart';

final quotationRepositoryProvider = Provider<QuotationRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return QuotationRepository(apiClient);
});

class QuotationRepository {
  final ApiClient _apiClient;

  QuotationRepository(this._apiClient);

  Future<List<QuotationModel>> getQuotations({String? status, String? search}) async {
    final queryParams = <String, dynamic>{};
    if (status != null && status != 'ALL') queryParams['status'] = status;
    if (search != null && search.isNotEmpty) queryParams['search'] = search;

    final response = await _apiClient.get(ApiConstants.quotations, queryParameters: queryParams);
    if (response['success'] == true && response['data'] is List) {
      return (response['data'] as List)
          .map((item) => QuotationModel.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    }
    return [];
  }

  Future<QuotationModel> getQuotationById(String id) async {
    final response = await _apiClient.get(ApiConstants.quotationDetail(id));
    if (response['success'] == true && response['data'] != null) {
      return QuotationModel.fromJson(Map<String, dynamic>.from(response['data'] as Map));
    }
    throw Exception(response['error'] ?? 'Failed to load quotation $id');
  }

  Future<QuotationModel> createQuotation({
    required String customerName,
    String? customerPhone,
    String? customerEmail,
    required List<Map<String, dynamic>> items,
    double tax = 0.0,
    String? dueDate,
    String? terms,
  }) async {
    final body = {
      'customer_name': customerName,
      if (customerPhone != null && customerPhone.isNotEmpty) 'customer_phone': customerPhone,
      if (customerEmail != null && customerEmail.isNotEmpty) 'customer_email': customerEmail,
      'items': items,
      'tax': tax,
      'due_date': ?dueDate,
      'terms': ?terms,
    };

    final response = await _apiClient.post(ApiConstants.quotations, data: body);
    if (response['success'] == true && response['data'] != null) {
      return QuotationModel.fromJson(Map<String, dynamic>.from(response['data'] as Map));
    }
    throw Exception(response['error'] ?? 'Failed to create quotation');
  }

  Future<void> updateStatus(String id, String status) async {
    final response = await _apiClient.patch(ApiConstants.quotationDetail(id), data: {'status': status});
    if (response['success'] != true) {
      throw Exception(response['error'] ?? 'Failed to update quotation');
    }
  }

  /// Creates an invoice from the quotation and returns the new invoice's id.
  Future<String> convertToInvoice(String id) async {
    final response = await _apiClient.post(ApiConstants.convertQuotation(id), data: {});
    if (response['success'] == true && response['data'] is Map) {
      return (response['data'] as Map)['id'].toString();
    }
    throw Exception(response['error'] ?? 'Failed to convert quotation');
  }

  Future<void> deleteQuotation(String id) async {
    await _apiClient.delete(ApiConstants.quotationDetail(id));
  }
}
