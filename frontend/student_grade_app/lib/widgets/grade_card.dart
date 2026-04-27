import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:grade_guardian/providers/grade_provider.dart';
import '../models/grade_record.dart';
import 'integrity_badge.dart';
import 'audit_log_sheet.dart';

/// Card widget to display a single grade record with integrity visualization
class GradeCard extends StatelessWidget {
  final GradeRecord grade;
  final VoidCallback? onTap;
  final VoidCallback? onRetryVerification;

  const GradeCard({
    Key? key,
    required this.grade,
    this.onTap,
    this.onRetryVerification,
  }) : super(key: key);

  void _viewLogs(BuildContext context, String gradeId) async {
    await Provider.of<GradeProvider>(context, listen: false).verifySingleGrade(gradeId);
    if (context.mounted) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => const AuditLogSheet(),
      );
    }
  }

  Color get _gradeColor {
    if (!grade.isVerified) return Colors.grey;

    if (grade.grade >= 90) return Colors.green;
    if (grade.grade >= 80) return Colors.blue;
    if (grade.grade >= 70) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = !grade.isVerified;

    return Card(
      elevation: grade.isVerified ? 2 : 4,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: grade.isVerified
              ? Colors.grey.shade200
              : Colors.red.shade300,
          width: grade.isVerified ? 1 : 2,
        ),
      ),
      child: InkWell(
        onTap: grade.isVerified ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Opacity(
          opacity: grade.isVerified ? 1.0 : 0.7,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with course info and integrity badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            grade.courseName,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.grey.shade700 : null,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            grade.courseCode,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IntegrityBadge(
                      isVerified: grade.isVerified,
                      errorMessage: grade.verificationError,
                      onRetry: onRetryVerification,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Grade display
                Row(
                  children: [
                    // Numeric grade
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: _gradeColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _gradeColor.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: Text(
                        grade.grade.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: _gradeColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Letter grade
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: _gradeColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        grade.letterGrade,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: _gradeColor,
                        ),
                      ),
                    ),

                    const Spacer(),

                    // Lock icon
                    Icon(
                      grade.isVerified ? Icons.lock : Icons.lock_open,
                      color: grade.isVerified
                          ? Colors.green.shade600
                          : Colors.red.shade600,
                      size: 28,
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Timestamp + Audit Log button row
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatDate(grade.recordedAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => _viewLogs(context, grade.id),
                      icon: const Icon(Icons.history, size: 16),
                      label: const Text('Audit Log', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),

                // Warning banner for tampered grades
                if (!grade.isVerified) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.red.shade700,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'This record has been compromised and should not be trusted',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.red.shade900,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}