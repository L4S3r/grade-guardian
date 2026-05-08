import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/grade_provider.dart';
import '../theme/app_theme.dart';

class AuditLogSheet extends StatelessWidget {
  const AuditLogSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final logs = context.watch<GradeProvider>().currentAuditLogs;

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: AppTheme.elevatedShadow,
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.cardBorder,
                  borderRadius: AppTheme.radiusFull,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Row(
                  children: [
                    const Icon(Icons.history_rounded, color: AppTheme.primary, size: 20),
                    const SizedBox(width: 8),
                    const Text('Integrity Audit Trail', style: AppTheme.titleMedium),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20, color: AppTheme.textHint),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppTheme.cardBorder),
              Expanded(
                child: logs.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history_toggle_off, size: 48, color: AppTheme.cardBorder),
                            SizedBox(height: 12),
                            Text('No history yet.', style: AppTheme.bodyMedium),
                          ],
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: logs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final log = logs[i];
                          final isPass = log.status == 'PASS';
                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isPass ? AppTheme.successLight : AppTheme.dangerLight,
                              borderRadius: AppTheme.radiusMd,
                              border: Border.all(
                                color: isPass ? AppTheme.successBorder : AppTheme.dangerBorder,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isPass ? Icons.check_circle : Icons.warning_amber_rounded,
                                  color: isPass ? AppTheme.success : AppTheme.danger,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(log.action,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: isPass ? AppTheme.success : AppTheme.danger,
                                          )),
                                      const SizedBox(height: 2),
                                      Text(
                                        _formatDate(log.checkedAt),
                                        style: AppTheme.labelSmall,
                                      ),
                                      if (log.errorDetails != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          log.errorDetails!,
                                          style: const TextStyle(
                                            fontSize: 11, color: AppTheme.danger,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(DateTime dt) {
    final l = dt.toLocal();
    return '${l.year}-${_p(l.month)}-${_p(l.day)}  ${_p(l.hour)}:${_p(l.minute)}';
  }

  String _p(int n) => n.toString().padLeft(2, '0');
}