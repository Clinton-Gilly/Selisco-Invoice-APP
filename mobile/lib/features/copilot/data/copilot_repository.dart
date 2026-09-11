import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/copilot_models.dart';

final copilotRepositoryProvider = Provider<CopilotRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return CopilotRepository(apiClient);
});

class CopilotRepository {
  final ApiClient _apiClient;

  CopilotRepository(this._apiClient);

  Future<Map<String, dynamic>> getConfig() async {
    final res = await _apiClient.get(ApiConstants.copilotConfig);
    if (res is Map && res['success'] == true && res['data'] is Map) {
      return Map<String, dynamic>.from(res['data'] as Map);
    }
    final errorMsg = (res is Map ? res['error'] : null) ?? 'Failed to load Copilot settings.';
    throw Exception(errorMsg);
  }

  Future<Map<String, dynamic>> saveConfig({
    required String provider,
    required String model,
    String? apiKey,
    bool? readOnly,
    bool? confirmWrites,
  }) async {
    final body = {
      'provider': provider,
      'model': model,
      if (apiKey != null && apiKey.isNotEmpty) 'apiKey': apiKey,
      'readOnly': ?readOnly,
      'confirmWrites': ?confirmWrites,
    };

    final res = await _apiClient.post(ApiConstants.copilotConfig, data: body);
    if (res is Map && res['success'] == true && res['data'] is Map) {
      return Map<String, dynamic>.from(res['data'] as Map);
    }
    final errorMsg = (res is Map ? res['error'] : null) ?? 'Failed to save Copilot settings.';
    throw Exception(errorMsg);
  }

  Future<String> testConnection({
    required String provider,
    required String model,
    required String apiKey,
  }) async {
    final body = {
      'provider': provider,
      'model': model,
      'apiKey': apiKey,
    };

    final res = await _apiClient.post(ApiConstants.copilotTest, data: body);
    if (res is Map && res['success'] == true) {
      return res['message'] as String? ?? 'Connection verified successfully!';
    }
    final errorMsg = (res is Map ? res['error'] : null) ?? 'Connection test failed.';
    throw Exception(errorMsg);
  }

  Future<Map<String, dynamic>> sendChatTurn({
    required List<Map<String, dynamic>> messages,
    ScreenContext? screenContext,
    Map<String, dynamic>? approvedCall,
    Map<String, dynamic>? declinedCall,
  }) async {
    final body = {
      'messages': messages,
      'screenContext': ?screenContext?.toJson(),
      'approvedCall': ?approvedCall,
      'declinedCall': ?declinedCall,
    };

    final res = await _apiClient.post(ApiConstants.copilotChat, data: body);
    if (res is Map && res['success'] == true && res['data'] is Map) {
      return Map<String, dynamic>.from(res['data'] as Map);
    }
    final errorMsg = (res is Map ? res['error'] : null) ?? 'Copilot turn failed.';
    throw Exception(errorMsg);
  }

  Future<String> undoAction(String auditLogId) async {
    final body = {'audit_log_id': auditLogId};
    final res = await _apiClient.post(ApiConstants.copilotUndo, data: body);
    if (res['success'] == true) {
      return res['message'] as String? ?? 'Action undone.';
    }
    throw Exception(res['error'] ?? 'Failed to undo action.');
  }
}
