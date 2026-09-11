import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/invoice_repository.dart';
import '../../models/invoice_model.dart';

class InvoiceFilterStatusNotifier extends Notifier<String> {
  @override
  String build() => 'ALL';

  void setFilter(String status) => state = status;
}

final invoiceFilterStatusProvider =
    NotifierProvider<InvoiceFilterStatusNotifier, String>(() {
  return InvoiceFilterStatusNotifier();
});

class InvoiceSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setSearch(String query) => state = query;
}

final invoiceSearchQueryProvider =
    NotifierProvider<InvoiceSearchQueryNotifier, String>(() {
  return InvoiceSearchQueryNotifier();
});

final invoicesListProvider = FutureProvider.autoDispose<List<InvoiceModel>>((ref) async {
  final repository = ref.watch(invoiceRepositoryProvider);
  final status = ref.watch(invoiceFilterStatusProvider);
  final search = ref.watch(invoiceSearchQueryProvider);

  return repository.getInvoices(status: status, search: search);
});

final invoiceDetailProvider =
    FutureProvider.autoDispose.family<InvoiceModel, String>((ref, id) async {
  final repository = ref.watch(invoiceRepositoryProvider);
  return repository.getInvoiceById(id);
});
