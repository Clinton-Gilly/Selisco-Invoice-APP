import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  final bool isDelivery;

  const StatusBadge({
    super.key,
    required this.status,
    this.isDelivery = false,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String label = status.toUpperCase();

    if (isDelivery) {
      switch (label) {
        case 'DELIVERED':
          bg = AppColors.successBg;
          fg = AppColors.success;
          label = 'Delivered';
          break;
        case 'IN_TRANSIT':
          bg = AppColors.infoBg;
          fg = AppColors.info;
          label = 'In Transit';
          break;
        case 'REJECTED':
          bg = AppColors.errorBg;
          fg = AppColors.error;
          label = 'Rejected';
          break;
        case 'PENDING':
        default:
          bg = AppColors.warningBg;
          fg = AppColors.warning;
          label = 'Pending';
          break;
      }
    } else {
      switch (label) {
        case 'PAID':
          bg = AppColors.successBg;
          fg = AppColors.success;
          label = 'Paid';
          break;
        case 'OVERDUE':
          bg = AppColors.errorBg;
          fg = AppColors.error;
          label = 'Overdue';
          break;
        case 'DRAFT':
          bg = AppColors.divider;
          fg = AppColors.textSecondary;
          label = 'Draft';
          break;
        case 'CANCELLED':
          bg = AppColors.errorBg;
          fg = AppColors.error;
          label = 'Cancelled';
          break;
        case 'ISSUED':
        default:
          bg = AppColors.infoBg;
          fg = AppColors.primary;
          label = 'Issued';
          break;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withValues(alpha: 0.2), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
