import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/student_auth_provider.dart';
import '../providers/grade_provider.dart';
import '../theme/app_theme.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final student = context.watch<StudentAuthProvider>().student!;
    final provider = context.watch<GradeProvider>();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => _confirmLogout(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Identity card ─────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primary, AppTheme.accent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: AppTheme.radiusLg,
              boxShadow: AppTheme.elevatedShadow,
            ),
            child: Row(
              children: [
                Container(
                  width: 68, height: 68,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person_rounded, color: Colors.white, size: 36),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(student.name,
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      _InfoRow(Icons.badge_outlined, student.studentId),
                      const SizedBox(height: 3),
                      _InfoRow(Icons.apartment_rounded, student.department),
                      const SizedBox(height: 3),
                      _InfoRow(Icons.email_outlined, student.email),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Integrity status ──────────────────────────────────────
          _IntegrityBanner(provider: provider),

          const SizedBox(height: 16),

          // ── Stats ─────────────────────────────────────────────────
          Row(
            children: [
              _StatTile('GPA', provider.gpa.toStringAsFixed(2), AppTheme.primary, Icons.school_rounded),
              const SizedBox(width: 10),
              _StatTile('Average', provider.averageGrade.toStringAsFixed(1), AppTheme.accent, Icons.analytics_rounded),
              const SizedBox(width: 10),
              _StatTile('Courses', provider.grades.length.toString(), AppTheme.success, Icons.menu_book_rounded),
            ],
          ),

          const SizedBox(height: 16),

          // ── Grade distribution ────────────────────────────────────
          _SectionCard(
            title: 'Grade Distribution',
            icon: Icons.bar_chart_rounded,
            child: _DistributionBars(distribution: provider.gradeDistribution, total: provider.grades.length),
          ),

          const SizedBox(height: 16),

          // ── Actions ───────────────────────────────────────────────
          _SectionCard(
            title: 'Actions',
            icon: Icons.tune_rounded,
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: provider.isVerifying ? null : provider.refresh,
                icon: provider.isVerifying
                    ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary))
                    : const Icon(Icons.verified_user_outlined),
                label: Text(provider.isVerifying ? 'Verifying…' : 'Re-verify All Grades'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                  side: const BorderSide(color: AppTheme.primary),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You will need to sign in again to view your grades.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<StudentAuthProvider>().logout();
              context.read<GradeProvider>().clear();
            },
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow(this.icon, this.text);

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, color: Colors.white70, size: 13),
          const SizedBox(width: 4),
          Flexible(
            child: Text(text,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      );
}

class _IntegrityBanner extends StatelessWidget {
  final GradeProvider provider;
  const _IntegrityBanner({required this.provider});

  @override
  Widget build(BuildContext context) {
    final isClean = !provider.hasTamperedGrades;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isClean ? AppTheme.successLight : AppTheme.dangerLight,
        borderRadius: AppTheme.radiusLg,
        border: Border.all(color: isClean ? AppTheme.successBorder : AppTheme.dangerBorder, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (isClean ? AppTheme.success : AppTheme.danger).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isClean ? Icons.verified_user : Icons.report_problem,
              color: isClean ? AppTheme.success : AppTheme.danger,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isClean ? 'All Records Verified' : 'Integrity Alert',
                  style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700,
                    color: isClean ? AppTheme.success : AppTheme.danger,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isClean
                      ? 'All ${provider.grades.length} of your grades passed HMAC integrity checks.'
                      : '${provider.tamperedGrades.length} record(s) may have been modified. Contact your academic office.',
                  style: AppTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label, value;
  final Color color;
  final IconData icon;
  const _StatTile(this.label, this.value, this.color, this.icon);

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.07),
            borderRadius: AppTheme.radiusMd,
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 6),
              Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
              const SizedBox(height: 2),
              Text(label, style: AppTheme.labelSmall, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
}

class _DistributionBars extends StatelessWidget {
  final Map<String, int> distribution;
  final int total;
  const _DistributionBars({required this.distribution, required this.total});

  @override
  Widget build(BuildContext context) {
    if (total == 0) return const Text('No grades yet', style: AppTheme.bodyMedium);
    final colors = {
      'A': AppTheme.success, 'B': AppTheme.primary,
      'C': AppTheme.warning, 'D': const Color(0xFFEA580C), 'F': AppTheme.danger,
    };
    return Column(
      children: ['A', 'B', 'C', 'D', 'F'].map((letter) {
        final count = distribution[letter] ?? 0;
        final pct = total > 0 ? count / total : 0.0;
        final color = colors[letter]!;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              SizedBox(
                width: 20,
                child: Text(letter, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ClipRRect(
                  borderRadius: AppTheme.radiusFull,
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 8,
                    backgroundColor: color.withOpacity(0.08),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 20,
                child: Text('$count', style: AppTheme.labelSmall.copyWith(color: color)),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _SectionCard({required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: AppTheme.radiusLg,
          border: Border.all(color: AppTheme.cardBorder),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 18, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(title, style: AppTheme.titleMedium),
            ]),
            const SizedBox(height: 14),
            child,
          ],
        ),
      );
}
