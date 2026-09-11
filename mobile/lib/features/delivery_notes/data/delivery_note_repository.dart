import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/delivery_note_model.dart';

final deliveryNoteRepositoryProvider = Provider<DeliveryNoteRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return DeliveryNoteRepository(apiClient);
});

class DeliveryNoteRepository {
  final ApiClient _apiClient;

  DeliveryNoteRepository(this._apiClient);

  Future<List<DeliveryNoteModel>> getDeliveryNotes({
    String? status,
    String? search,
  }) async {
    final queryParams = <String, dynamic>{};
    if (status != null && status != 'ALL') {
      queryParams['status'] = status;
    }
    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }

    final response = await _apiClient.get(
      ApiConstants.deliveryNotes,
      queryParameters: queryParams,
    );

    if (response['success'] == true && response['data'] is List) {
      return (response['data'] as List)
          .map((item) => DeliveryNoteModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<DeliveryNoteModel> getDeliveryNoteById(String id) async {
    final response = await _apiClient.get(ApiConstants.deliveryNoteDetail(id));
    if (response['success'] == true && response['data'] != null) {
      return DeliveryNoteModel.fromJson(response['data'] as Map<String, dynamic>);
    }
    throw Exception('Failed to load delivery note $id');
  }

  Future<DeliveryNoteModel> updateDeliveryNote(
    String id, {
    String? status,
    String? recipientName,
    String? notes,
    String? deliveredAt,
    List<DeliveryNoteItemModel>? items,
  }) async {
    final body = <String, dynamic>{};
    if (status != null) body['status'] = status;
    if (recipientName != null) body['recipient_name'] = recipientName;
    if (notes != null) body['notes'] = notes;
    if (deliveredAt != null) body['delivered_at'] = deliveredAt;
    if (items != null) {
      body['items'] = items.map((i) => {
        'id': i.id,
        'delivered_quantity': i.deliveredQuantity,
      }).toList();
    }

    final response = await _apiClient.patch(
      ApiConstants.deliveryNoteDetail(id),
      data: body,
    );

    if (response['success'] == true && response['data'] != null) {
      return DeliveryNoteModel.fromJson(response['data'] as Map<String, dynamic>);
    }
    throw Exception('Failed to update delivery note');
  }
}
