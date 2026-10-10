import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/quotation_repository.dart';
import '../../models/quotation_model.dart';

class QuotationFilterStatusNotifier extends Notifier<String> {
  @override
  String build() => 'ALL';

  void setFilter(String status) => state = status;
}

final quotationFilterStatusProvider =
    NotifierProvider<QuotationFilterStatusNotifier, String>(() {
  return QuotationFilterStatusNotifier();
});

class QuotationSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setSearch(String query) => state = query;
}

final quotationSearchQueryProvider =
    NotifierProvider<QuotationSearchQueryNotifier, String>(() {
  return QuotationSearchQueryNotifier();
});

final quotationsListProvider = FutureProvider.autoDispose<List<QuotationModel>>((ref) async {
  final repository = ref.watch(quotationRepositoryProvider);
  final status = ref.watch(quotationFilterStatusProvider);
  final search = ref.watch(quotationSearchQueryProvider);

  return repository.getQuotations(status: status, search: search);
});

final quotationDetailProvider =
    FutureProvider.autoDispose.family<QuotationModel, String>((ref, id) async {
  final repository = ref.watch(quotationRepositoryProvider);
  return repository.getQuotationById(id);
});
