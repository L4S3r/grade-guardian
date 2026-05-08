import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class IntegrityBadge extends StatelessWidget {
  final bool isVerified;
  final bool isVerifying;
  final String? errorMessage;
  final VoidCallback? onRetry;

  const IntegrityBadge({
    Key? key,
    required this.isVerified,
    this.isVerifying = false,
    this.errorMessage,
    this.onRetry,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isVerifying) return _buildVerifying();
    if (isVerified) return _buildVerified();
    return _buildTampered();
  }

  Widget _buildVerifying() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFE3F2FD),
          borderRadius: AppTheme.radiusFull,
          border: Border.all(color: const Color(0xFF90CAF9)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14, height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
            ),
            SizedBox(width: 6),
            Text('Checking…', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.primary)),
          ],
        ),
      );

  Widget _buildVerified() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppTheme.successLight,
          borderRadius: AppTheme.radiusFull,
          border: Border.all(color: AppTheme.successBorder),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified_user, color: AppTheme.success, size: 14),
            SizedBox(width: 4),
            Text('Verified', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.success)),
          ],
        ),
      );

  Widget _buildTampered() => GestureDetector(
        onTap: onRetry,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppTheme.dangerLight,
            borderRadius: AppTheme.radiusFull,
            border: Border.all(color: AppTheme.dangerBorder, width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.report_problem, color: AppTheme.danger, size: 14),
              const SizedBox(width: 4),
              const Text('Tampered', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.danger)),
              if (onRetry != null) ...[
                const SizedBox(width: 3),
                const Icon(Icons.refresh, color: AppTheme.danger, size: 12),
              ],
            ],
          ),
        ),
      );
}