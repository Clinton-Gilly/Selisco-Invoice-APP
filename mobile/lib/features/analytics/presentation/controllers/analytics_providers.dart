import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/analytics_repository.dart';
import '../../models/analytics_model.dart';

final analyticsProvider = FutureProvider.autoDispose<AnalyticsModel>((ref) async {
  final repository = ref.watch(analyticsRepositoryProvider);
  return repository.getAnalytics();
});
