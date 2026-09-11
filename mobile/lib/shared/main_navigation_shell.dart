import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/app_colors.dart';
import '../features/invoices/presentation/screens/invoice_list_screen.dart';
import '../features/delivery_notes/presentation/screens/delivery_note_list_screen.dart';
import '../features/analytics/presentation/screens/analytics_dashboard_screen.dart';
import '../features/products/presentation/screens/product_catalog_screen.dart';
import '../features/copilot/services/screen_context_service.dart';

class MainNavigationShell extends ConsumerStatefulWidget {
  const MainNavigationShell({super.key});

  @override
  ConsumerState<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends ConsumerState<MainNavigationShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    InvoiceListScreen(),
    DeliveryNoteListScreen(),
    ProductCatalogScreen(),
    AnalyticsDashboardScreen(),
  ];

  void _onTabSelected(int index) {
    setState(() => _currentIndex = index);

    final contextNotifier = ref.read(screenContextProvider.notifier);
    switch (index) {
      case 0:
        contextNotifier.updateScreen(
          route: '/invoices',
          screenName: 'Invoices',
          customNote: 'Invoices list dashboard showing issued, paid, and overdue invoices.',
        );
        break;
      case 1:
        contextNotifier.updateScreen(
          route: '/deliveries',
          screenName: 'Delivery Notes',
          customNote: 'Delivery tracking screen for dispatch and delivery receipts.',
        );
        break;
      case 2:
        contextNotifier.updateScreen(
          route: '/catalog',
          screenName: 'Product Catalog',
          customNote: 'Surgical & orthopaedic implants and instruments catalog with pricing.',
        );
        break;
      case 3:
        contextNotifier.updateScreen(
          route: '/analytics',
          screenName: 'Analytics',
          customNote: 'Financial intelligence: total revenue, outstanding amounts, and delivery completion rates.',
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border, width: 1)),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: _onTabSelected,
          backgroundColor: AppColors.surface,
          indicatorColor: AppColors.primary.withValues(alpha: 0.12),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long, color: AppColors.primary),
              label: 'Invoices',
            ),
            NavigationDestination(
              icon: Icon(Icons.local_shipping_outlined),
              selectedIcon: Icon(Icons.local_shipping, color: AppColors.primary),
              label: 'Deliveries',
            ),
            NavigationDestination(
              icon: Icon(Icons.inventory_2_outlined),
              selectedIcon: Icon(Icons.inventory_2, color: AppColors.primary),
              label: 'Catalog',
            ),
            NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined),
              selectedIcon: Icon(Icons.bar_chart, color: AppColors.primary),
              label: 'Analytics',
            ),
          ],
        ),
      ),
    );
  }
}
