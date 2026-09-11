import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/analytics_model.dart';

final analyticsRepositoryProvider = Provider<AnalyticsRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AnalyticsRepository(apiClient);
});

class AnalyticsRepository {
  final ApiClient _apiClient;

  AnalyticsRepository(this._apiClient);

  Future<AnalyticsModel> getAnalytics() async {
    final response = await _apiClient.get(ApiConstants.analytics);
    if (response['success'] == true && response['data'] != null) {
      return AnalyticsModel.fromJson(response['data'] as Map<String, dynamic>);
    }
    throw Exception('Failed to fetch analytics summary');
  }
}
