import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/invoice_model.dart';

final invoiceRepositoryProvider = Provider<InvoiceRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return InvoiceRepository(apiClient);
});

class InvoiceRepository {
  final ApiClient _apiClient;

  InvoiceRepository(this._apiClient);

  Future<List<InvoiceModel>> getInvoices({String? status, String? search}) async {
    final queryParams = <String, dynamic>{};
    if (status != null && status != 'ALL') {
      queryParams['status'] = status;
    }
    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }

    final response = await _apiClient.get(
      ApiConstants.invoices,
      queryParameters: queryParams,
    );

    if (response['success'] == true && response['data'] is List) {
      return (response['data'] as List)
          .map((item) => InvoiceModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<InvoiceModel> getInvoiceById(String id) async {
    final response = await _apiClient.get(ApiConstants.invoiceDetail(id));
    if (response['success'] == true && response['data'] != null) {
      return InvoiceModel.fromJson(response['data'] as Map<String, dynamic>);
    }
    throw Exception('Failed to load invoice $id');
  }

  Future<InvoiceModel> createInvoice({
    required String customerName,
    String? customerPhone,
    String? customerEmail,
    String? customerPin,
    required List<Map<String, dynamic>> items,
    double tax = 0.0,
    String? issuedDate,
    String? dueDate,
    String? notes,
  }) async {
    final body = {
      'customer_name': customerName,
      if (customerPhone != null && customerPhone.isNotEmpty) 'customer_phone': customerPhone,
      if (customerEmail != null && customerEmail.isNotEmpty) 'customer_email': customerEmail,
      if (customerPin != null && customerPin.isNotEmpty) 'customer_pin': customerPin,
      'items': items,
      'tax': tax,
      'issued_date': ?issuedDate,
      'due_date': ?dueDate,
      'notes': ?notes,
    };

    final response = await _apiClient.post(ApiConstants.invoices, data: body);
    if (response['success'] == true && response['data'] != null) {
      return InvoiceModel.fromJson(response['data'] as Map<String, dynamic>);
    }
    throw Exception(response['error'] ?? 'Failed to create invoice');
  }

  Future<void> updateInvoiceStatus(String id, String status) async {
    await _apiClient.patch(
      ApiConstants.invoiceDetail(id),
      data: {'status': status},
    );
  }

  Future<Map<String, dynamic>> convertToDeliveryNote(
    String id, {
    String? recipientName,
    String? notes,
  }) async {
    final body = {
      'recipient_name': ?recipientName,
      'notes': ?notes,
    };

    final response = await _apiClient.post(
      ApiConstants.convertInvoice(id),
      data: body,
    );

    if (response['success'] == true && response['data'] != null) {
      return response['data'] as Map<String, dynamic>;
    }
    throw Exception(response['error'] ?? 'Failed to convert invoice to delivery note');
  }

  Future<void> deleteInvoice(String id) async {
    await _apiClient.delete(ApiConstants.invoiceDetail(id));
  }
}
