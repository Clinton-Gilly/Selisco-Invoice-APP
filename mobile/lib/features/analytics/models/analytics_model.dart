class MonthlyTrend {
  final String month;
  final double revenue;
  final int count;

  const MonthlyTrend({
    required this.month,
    required this.revenue,
    required this.count,
  });

  factory MonthlyTrend.fromJson(Map<String, dynamic> json) {
    return MonthlyTrend(
      month: json['month']?.toString() ?? '',
      revenue: double.tryParse(json['revenue']?.toString() ?? '0') ?? 0.0,
      count: int.tryParse(json['count']?.toString() ?? '0') ?? 0,
    );
  }
}

class AnalyticsModel {
  final double totalRevenue;
  final double pendingAmount;
  final double grossBilled;
  final int totalInvoices;
  final int paidInvoices;
  final int pendingInvoices;
  final int overdueInvoices;
  final int totalDeliveries;
  final int deliveredCount;
  final int inTransitCount;
  final int pendingDeliveries;
  final int rejectedDeliveries;
  final double deliverySuccessRate;
  final List<MonthlyTrend> monthlyTrends;

  const AnalyticsModel({
    required this.totalRevenue,
    required this.pendingAmount,
    required this.grossBilled,
    required this.totalInvoices,
    required this.paidInvoices,
    required this.pendingInvoices,
    required this.overdueInvoices,
    required this.totalDeliveries,
    required this.deliveredCount,
    required this.inTransitCount,
    required this.pendingDeliveries,
    required this.rejectedDeliveries,
    required this.deliverySuccessRate,
    required this.monthlyTrends,
  });

  factory AnalyticsModel.fromJson(Map<String, dynamic> json) {
    var rawTrends = json['monthly_trends'];
    List<MonthlyTrend> parsedTrends = [];
    if (rawTrends is List) {
      parsedTrends = rawTrends
          .map((t) => MonthlyTrend.fromJson(t as Map<String, dynamic>))
          .toList();
    }

    return AnalyticsModel(
      totalRevenue:
          double.tryParse(json['total_revenue']?.toString() ?? '0') ?? 0.0,
      pendingAmount:
          double.tryParse(json['pending_amount']?.toString() ?? '0') ?? 0.0,
      grossBilled:
          double.tryParse(json['gross_billed']?.toString() ?? '0') ?? 0.0,
      totalInvoices:
          int.tryParse(json['total_invoices']?.toString() ?? '0') ?? 0,
      paidInvoices:
          int.tryParse(json['paid_invoices']?.toString() ?? '0') ?? 0,
      pendingInvoices:
          int.tryParse(json['pending_invoices']?.toString() ?? '0') ?? 0,
      overdueInvoices:
          int.tryParse(json['overdue_invoices']?.toString() ?? '0') ?? 0,
      totalDeliveries:
          int.tryParse(json['total_deliveries']?.toString() ?? '0') ?? 0,
      deliveredCount:
          int.tryParse(json['delivered_count']?.toString() ?? '0') ?? 0,
      inTransitCount:
          int.tryParse(json['in_transit_count']?.toString() ?? '0') ?? 0,
      pendingDeliveries:
          int.tryParse(json['pending_deliveries']?.toString() ?? '0') ?? 0,
      rejectedDeliveries:
          int.tryParse(json['rejected_deliveries']?.toString() ?? '0') ?? 0,
      deliverySuccessRate:
          double.tryParse(json['delivery_success_rate']?.toString() ?? '100') ??
              100.0,
      monthlyTrends: parsedTrends,
    );
  }
}
