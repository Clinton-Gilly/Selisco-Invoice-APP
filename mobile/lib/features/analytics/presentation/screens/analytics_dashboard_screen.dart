import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../models/analytics_model.dart';
import '../controllers/analytics_providers.dart';
import '../../../copilot/presentation/screens/copilot_sheet.dart';
import '../../../copilot/services/screen_context_service.dart';

class AnalyticsDashboardScreen extends ConsumerWidget {
  const AnalyticsDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analyticsAsync = ref.watch(analyticsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Executive Analytics'),
        actions: [
          // Prominent Eye-Catching AI Assistant Button
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  ref.read(screenContextProvider.notifier).updateScreen(
                    route: '/analytics',
                    screenName: 'Analytics',
                    customNote: 'Executive analytics dashboard showing total revenue, collections, and delivery rates.',
                  );
                  CopilotSheet.show(context);
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome, color: Colors.white, size: 15),
                      SizedBox(width: 5),
                      Text(
                        'AI Assistant',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(analyticsProvider),
          ),
        ],
      ),
      body: analyticsAsync.when(
        data: (data) {
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(analyticsProvider),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Top KPI Grid
                Row(
                  children: [
                    Expanded(
                      child: _buildKpiCard(
                        title: 'Total Revenue',
                        value: Formatters.currency(data.totalRevenue),
                        subtitle: '${data.paidInvoices} paid invoices',
                        icon: Icons.payments_outlined,
                        color: AppColors.success,
                        bgColor: AppColors.successBg,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildKpiCard(
                        title: 'Pending Invoices',
                        value: Formatters.currency(data.pendingAmount),
                        subtitle: '${data.pendingInvoices} unpaid',
                        icon: Icons.pending_actions_outlined,
                        color: AppColors.warning,
                        bgColor: AppColors.warningBg,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildKpiCard(
                        title: 'Delivery Rate',
                        value: '${data.deliverySuccessRate.toStringAsFixed(1)}%',
                        subtitle: '${data.deliveredCount}/${data.totalDeliveries} delivered',
                        icon: Icons.verified_outlined,
                        color: AppColors.primary,
                        bgColor: AppColors.infoBg,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildKpiCard(
                        title: 'Total Invoiced',
                        value: Formatters.currency(data.grossBilled),
                        subtitle: '${data.totalInvoices} total documents',
                        icon: Icons.receipt_long_outlined,
                        color: AppColors.primaryDark,
                        bgColor: AppColors.divider,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Visual Monthly Revenue Trend Chart (fl_chart)
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Revenue Trend',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Last 6 Months',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Monthly invoiced billing totals across all clients',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 24),
                      // fl_chart container
                      SizedBox(
                        height: 200,
                        child: data.monthlyTrends.isEmpty
                            ? const Center(
                                child: Text('No historical trends available yet',
                                    style: TextStyle(color: AppColors.textMuted)),
                              )
                            : BarChart(
                                BarChartData(
                                  alignment: BarChartAlignment.spaceAround,
                                  maxY: _calculateMaxY(data.monthlyTrends),
                                  barTouchData: BarTouchData(
                                    enabled: true,
                                    touchTooltipData: BarTouchTooltipData(
                                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                        final trend = data.monthlyTrends[group.x.toInt()];
                                        return BarTooltipItem(
                                          '${trend.month}\n',
                                          const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                          children: [
                                            TextSpan(
                                              text: Formatters.currency(trend.revenue),
                                              style: const TextStyle(
                                                color: Colors.amberAccent,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                  titlesData: FlTitlesData(
                                    show: true,
                                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    leftTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        reservedSize: 45,
                                        getTitlesWidget: (val, meta) {
                                          if (val == 0) return const SizedBox.shrink();
                                          return Text(
                                            '\$${(val / 1000).toStringAsFixed(1)}k',
                                            style: const TextStyle(
                                              color: AppColors.textMuted,
                                              fontSize: 10,
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    bottomTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        getTitlesWidget: (val, meta) {
                                          final idx = val.toInt();
                                          if (idx >= 0 && idx < data.monthlyTrends.length) {
                                            return Padding(
                                              padding: const EdgeInsets.only(top: 8.0),
                                              child: Text(
                                                data.monthlyTrends[idx].month.split(' ')[0],
                                                style: const TextStyle(
                                                  color: AppColors.textSecondary,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            );
                                          }
                                          return const SizedBox.shrink();
                                        },
                                      ),
                                    ),
                                  ),
                                  gridData: FlGridData(
                                    show: true,
                                    drawVerticalLine: false,
                                    horizontalInterval: _calculateInterval(data.monthlyTrends),
                                    getDrawingHorizontalLine: (val) => const FlLine(
                                      color: AppColors.divider,
                                      strokeWidth: 1,
                                    ),
                                  ),
                                  borderData: FlBorderData(show: false),
                                  barGroups: data.monthlyTrends.asMap().entries.map((entry) {
                                    final idx = entry.key;
                                    final item = entry.value;
                                    return BarChartGroupData(
                                      x: idx,
                                      barRods: [
                                        BarChartRodData(
                                          toY: item.revenue,
                                          gradient: const LinearGradient(
                                            colors: [AppColors.primaryLight, AppColors.primary],
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                          ),
                                          width: 22,
                                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Deliveries & Invoices Breakdown Cards
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Delivery Fulfillment Status',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          _buildStatusItem('Delivered', data.deliveredCount, AppColors.success),
                          _buildStatusItem('In Transit', data.inTransitCount, AppColors.info),
                          _buildStatusItem('Pending', data.pendingDeliveries, AppColors.warning),
                          _buildStatusItem('Rejected', data.rejectedDeliveries, AppColors.error),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusItem(String label, int count, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            count.toString(),
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  double _calculateMaxY(List<MonthlyTrend> monthlyTrends) {
    double max = 1000.0;
    for (var m in monthlyTrends) {
      if (m.revenue > max) max = m.revenue;
    }
    return max * 1.25;
  }

  double _calculateInterval(List<MonthlyTrend> monthlyTrends) {
    final max = _calculateMaxY(monthlyTrends);
    return max / 4 > 0 ? max / 4 : 500.0;
  }
}
