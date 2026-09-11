import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/product_repository.dart';
import '../../models/product_model.dart';

class ProductSearchNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setSearch(String query) => state = query;
}

final productSearchProvider = NotifierProvider<ProductSearchNotifier, String>(() {
  return ProductSearchNotifier();
});

final productsListProvider = FutureProvider.autoDispose<List<ProductModel>>((ref) async {
  final repository = ref.watch(productRepositoryProvider);
  final search = ref.watch(productSearchProvider);
  return repository.getProducts(search: search);
});
