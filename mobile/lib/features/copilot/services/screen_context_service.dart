import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/copilot_models.dart';

class ScreenContextNotifier extends Notifier<ScreenContext> {
  @override
  ScreenContext build() {
    return const ScreenContext(
      route: '/invoices',
      screenName: 'Invoices',
      activeTab: 'ALL',
      customNote: 'Invoices list screen with quick filters and actions.',
    );
  }

  void updateScreen({
    required String route,
    required String screenName,
    String? activeTab,
    int? visibleCount,
    Map<String, dynamic>? activeRecord,
    Map<String, dynamic>? formData,
    String? customNote,
  }) {
    state = ScreenContext(
      route: route,
      screenName: screenName,
      activeTab: activeTab ?? state.activeTab,
      visibleCount: visibleCount ?? state.visibleCount,
      activeRecord: activeRecord ?? state.activeRecord,
      formData: formData ?? state.formData,
      customNote: customNote ?? state.customNote,
    );
  }

  void setActiveRecord(Map<String, dynamic>? record) {
    state = ScreenContext(
      route: state.route,
      screenName: state.screenName,
      activeTab: state.activeTab,
      visibleCount: state.visibleCount,
      activeRecord: record,
      formData: state.formData,
      customNote: state.customNote,
    );
  }

  void updateFormData(Map<String, dynamic>? formData) {
    state = ScreenContext(
      route: state.route,
      screenName: state.screenName,
      activeTab: state.activeTab,
      visibleCount: state.visibleCount,
      activeRecord: state.activeRecord,
      formData: formData,
      customNote: state.customNote,
    );
  }
}

final screenContextProvider =
    NotifierProvider<ScreenContextNotifier, ScreenContext>(() {
  return ScreenContextNotifier();
});
