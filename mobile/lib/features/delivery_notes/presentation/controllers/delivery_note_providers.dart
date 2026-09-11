import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/delivery_note_repository.dart';
import '../../models/delivery_note_model.dart';

class DeliveryFilterStatusNotifier extends Notifier<String> {
  @override
  String build() => 'ALL';

  void setFilter(String status) => state = status;
}

final deliveryFilterStatusProvider =
    NotifierProvider<DeliveryFilterStatusNotifier, String>(() {
  return DeliveryFilterStatusNotifier();
});

class DeliverySearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setSearch(String query) => state = query;
}

final deliverySearchQueryProvider =
    NotifierProvider<DeliverySearchQueryNotifier, String>(() {
  return DeliverySearchQueryNotifier();
});

final deliveryNotesListProvider =
    FutureProvider.autoDispose<List<DeliveryNoteModel>>((ref) async {
  final repository = ref.watch(deliveryNoteRepositoryProvider);
  final status = ref.watch(deliveryFilterStatusProvider);
  final search = ref.watch(deliverySearchQueryProvider);

  return repository.getDeliveryNotes(status: status, search: search);
});

final deliveryNoteDetailProvider =
    FutureProvider.autoDispose.family<DeliveryNoteModel, String>((ref, id) async {
  final repository = ref.watch(deliveryNoteRepositoryProvider);
  return repository.getDeliveryNoteById(id);
});
