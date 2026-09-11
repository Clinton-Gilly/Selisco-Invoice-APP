import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../models/copilot_models.dart';

class ScreenContextPill extends StatelessWidget {
  final ScreenContext context;
  final VoidCallback? onTap;

  const ScreenContextPill({
    super.key,
    required this.context,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap ??
          () {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Row(
                  children: [
                    const Icon(Icons.remove_red_eye_outlined, color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    const Text('Screen Awareness', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'The Copilot reads this runtime context to answer accurately:',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    _buildRow('Active Screen', this.context.screenName),
                    _buildRow('Route Path', this.context.route),
                    if (this.context.activeTab != null)
                      _buildRow('Active Filter/Tab', this.context.activeTab!),
                    if (this.context.visibleCount != null)
                      _buildRow('Records Visible', '${this.context.visibleCount} items'),
                    if (this.context.customNote != null)
                      _buildRow('Screen State', this.context.customNote!),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Dismiss'),
                  ),
                ],
              ),
            );
          },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: AppColors.success,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              this.context.screenName,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
