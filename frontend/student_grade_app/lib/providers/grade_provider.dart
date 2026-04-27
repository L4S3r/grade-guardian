import 'package:flutter/foundation.dart';
import 'package:grade_guardian/models/audit_log.dart';
import '../models/grade_record.dart';
import '../services/api_service.dart';

/// Enum to represent the loading state
enum GradeLoadingState {
  idle,
  loading,
  success,
  error,
}

/// Provider class to manage grade state across the app
class GradeProvider extends ChangeNotifier {
  final ApiService _apiService;
  List<GradeRecord> _grades = [];
  List<AuditLog> _currentAuditLogs = [];
  List<AuditLog> get currentAuditLogs => _currentAuditLogs;
  GradeLoadingState _loadingState = GradeLoadingState.idle;
  String? _errorMessage;
  bool _isVerifying = false;

  GradeProvider(this._apiService);

  // Getters
  List<GradeRecord> get grades => List.unmodifiable(_grades);
  GradeLoadingState get loadingState => _loadingState;
  String? get errorMessage => _errorMessage;
  bool get isVerifying => _isVerifying;
  bool get hasError => _loadingState == GradeLoadingState.error;
  bool get isLoading => _loadingState == GradeLoadingState.loading;

  /// Get only verified grades
  List<GradeRecord> get verifiedGrades =>
      _grades.where((grade) => grade.isVerified).toList();

  /// Get only tampered/unverified grades
  List<GradeRecord> get tamperedGrades =>
      _grades.where((grade) => !grade.isVerified).toList();

  /// Check if any grade has been tampered with
  bool get hasTamperedGrades => tamperedGrades.isNotEmpty;

  /// Load all grades for a student
  Future<void> loadGrades({String? studentId}) async {
    _loadingState = GradeLoadingState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _grades = await _apiService.fetchGrades(studentId: studentId);
      _loadingState = GradeLoadingState.success;

      // Automatically verify grades after loading
      await verifyAllGrades();
    } catch (e) {
      _loadingState = GradeLoadingState.error;
      _errorMessage = e.toString();
      _grades = [];
    } finally {
      notifyListeners();
    }
  }

  /// Submit a new grade
  Future<bool> submitGrade({
    required String studentId,
    required String courseName,
    required String courseCode,
    required double grade,
    required String letterGrade,
  }) async {
    try {
      final newGrade = await _apiService.submitGrade(
        studentId: studentId,
        courseName: courseName,
        courseCode: courseCode,
        grade: grade,
        letterGrade: letterGrade,
      );

      _grades.insert(0, newGrade);
      notifyListeners();

      return true;
    } catch (e, stacktrace) {
      debugPrint("--- SUBMIT ERROR DETECTED ---");
      debugPrint("Error: $e");
      debugPrint("Stacktrace: $stacktrace");
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Verify all grades
  Future<void> verifyAllGrades() async {
    if (_grades.isEmpty) return;

    _isVerifying = true;
    notifyListeners();

    try {
      final gradeIds = _grades.map((g) => g.id).toList();
      final List<Map<String, dynamic>> verificationResults =
          await _apiService.verifyMultipleGrades(gradeIds);

      for (var i = 0; i < _grades.length; i++) {
        final result = verificationResults.firstWhere(
          (r) => r['grade_id'] == _grades[i].id,
          orElse: () => {'is_valid': false, 'error': 'No data'},
        );

        _grades[i] = _grades[i].copyWith(
          isVerified: (result['is_valid'] ?? false) as bool,
          verificationError: result['error'] as String?,
        );
      }
    } catch (e) {
      debugPrint('Batch Verification error: $e');
    } finally {
      _isVerifying = false;
      notifyListeners();
    }
  }

  /// Verify a single grade and load its audit logs
  Future<void> verifySingleGrade(String gradeId) async {
  final index = _grades.indexWhere((g) => g.id == gradeId);
  if (index == -1) return;

  try {
    // Fetch verify result and logs in parallel
    final results = await Future.wait([
      _apiService.verifyGrade(gradeId),
      _apiService.fetchGradeLogs(gradeId),
    ]);

    final verifyResult = results[0] as Map<String, dynamic>;
    final logs = results[1] as List<AuditLog>;

    _grades[index] = _grades[index].copyWith(
      isVerified: verifyResult['is_valid'] ?? false,
      verificationError: verifyResult['error'] as String?,
    );
    _currentAuditLogs = logs;

  } catch (e) {
    debugPrint('verifySingleGrade error: $e');
    // ⚠️ DON'T touch isVerified here — only update the logs
    // Failing to fetch logs is not evidence of tampering
    _currentAuditLogs = [];
  } finally {
    notifyListeners();
  }
}

  /// Refresh grades and re-verify
  Future<void> refresh({String? studentId}) async {
    await loadGrades(studentId: studentId);
  }

  /// Clear all grades
  void clear() {
    _grades = [];
    _loadingState = GradeLoadingState.idle;
    _errorMessage = null;
    _isVerifying = false;
    notifyListeners();
  }
}