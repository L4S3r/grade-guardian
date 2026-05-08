import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/grade_provider.dart';
import '../providers/student_auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/grade_card.dart';

class GradesScreen extends StatefulWidget {
  const GradesScreen({Key? key}) : super(key: key);

  @override
  State<GradesScreen> createState() => _GradesScreenState();
}

class _GradesScreenState extends State<GradesScreen> {
  String _sortOption = 'Date (Newest)';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GradeProvider>().loadGrades();
    });
  }

  @override
  Widget build(BuildContext context) {
    final student = context.watch<StudentAuthProvider>().student;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Column(
          children: [
            const Text('My Grades'),
            if (student != null)
              Text(
                student.studentId,
                style: const TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w400),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () => context.read<GradeProvider>().refresh(),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort_rounded),
            tooltip: 'Sort',
            onSelected: (v) => setState(() => _sortOption = v),
            itemBuilder: (_) => [
              'Date (Newest)',
              'Grade (High to Low)',
              'Course Code (A-Z)',
            ].map((s) => PopupMenuItem(value: s, child: Text(s))).toList(),
          ),
        ],
      ),
      body: Consumer<GradeProvider>(
        builder: (context, provider, _) {
          return Column(
            children: [
              if (provider.hasTamperedGrades) _TamperBanner(provider: provider),
              if (provider.isVerifying) _VerifyingBar(),
              Expanded(child: _buildBody(provider)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBody(GradeProvider provider) {
    if (provider.isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppTheme.primary),
            SizedBox(height: 16),
            Text('Loading your grades…', style: AppTheme.bodyMedium),
          ],
        ),
      );
    }

    if (provider.hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: AppTheme.danger),
              const SizedBox(height: 16),
              const Text('Could not load grades', style: AppTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(
                provider.errorMessage ?? 'Unknown error',
                style: AppTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: provider.refresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (provider.grades.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.07),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.school_outlined, size: 56, color: AppTheme.primary),
            ),
            const SizedBox(height: 20),
            const Text('No grades recorded yet', style: AppTheme.headlineMedium),
            const SizedBox(height: 8),
            const Text(
              'Your grades will appear here once\nyour professors submit them.',
              style: AppTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Sort
    var grades = provider.grades.toList();
    if (_sortOption == 'Grade (High to Low)') {
      grades.sort((a, b) => b.grade.compareTo(a.grade));
    } else if (_sortOption == 'Course Code (A-Z)') {
      grades.sort((a, b) => a.courseCode.compareTo(b.courseCode));
    } else {
      grades.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    }

    return RefreshIndicator(
      onRefresh: provider.refresh,
      color: AppTheme.primary,
      child: CustomScrollView(
        slivers: [
          // ── GPA Summary Card ─────────────────────────────────────
          SliverToBoxAdapter(
            child: _GpaSummaryCard(provider: provider),
          ),

          // ── Grade List ────────────────────────────────────────────
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => GradeCard(
                grade: grades[index],
                onRetryVerification: () => provider.refresh(),
              ),
              childCount: grades.length,
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

// ── GPA Summary ──────────────────────────────────────────────────────────────
class _GpaSummaryCard extends StatelessWidget {
  final GradeProvider provider;
  const _GpaSummaryCard({required this.provider});

  String _gpaLabel(double gpa) {
    if (gpa >= 3.7) return 'Summa Cum Laude';
    if (gpa >= 3.5) return 'Magna Cum Laude';
    if (gpa >= 3.0) return 'Good Standing';
    if (gpa >= 2.0) return 'Satisfactory';
    if (gpa > 0) return 'Needs Improvement';
    return 'No verified grades';
  }

  @override
  Widget build(BuildContext context) {
    final gpa = provider.gpa;
    final avg = provider.averageGrade;
    final total = provider.grades.length;
    final verified = provider.verifiedGrades.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Container(
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Cumulative GPA',
                    style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    gpa.toStringAsFixed(2),
                    style: const TextStyle(
                      color: Colors.white, fontSize: 46,
                      fontWeight: FontWeight.w900, letterSpacing: -1,
                    ),
                  ),
                  Text(
                    _gpaLabel(gpa),
                    style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _Stat('Avg Score', avg.toStringAsFixed(1)),
                const SizedBox(height: 8),
                _Stat('Courses', total.toString()),
                const SizedBox(height: 8),
                _Stat('Verified', '$verified / $total'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label, value;
  const _Stat(this.label, this.value);

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.w500)),
        ],
      );
}

// ── Tamper Banner ─────────────────────────────────────────────────────────────
class _TamperBanner extends StatelessWidget {
  final GradeProvider provider;
  const _TamperBanner({required this.provider});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: AppTheme.danger,
        child: Row(
          children: [
            const Icon(Icons.report_problem, color: Colors.white, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${provider.tamperedGrades.length} record(s) may have been altered. Contact your academic office.',
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
}

// ── Verifying Bar ─────────────────────────────────────────────────────────────
class _VerifyingBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        color: AppTheme.primary.withOpacity(0.08),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 14, height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
            ),
            SizedBox(width: 10),
            Text('Verifying integrity…',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primary)),
          ],
        ),
      );
}