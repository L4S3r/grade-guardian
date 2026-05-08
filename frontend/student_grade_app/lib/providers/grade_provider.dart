import 'package:flutter/foundation.dart';
import '../models/grade_record.dart';
import '../models/audit_log.dart';
import '../services/api_service.dart';

enum GradeLoadingState { idle, loading, success, error }

class GradeProvider extends ChangeNotifier {
  final ApiService _api;

  List<GradeRecord> _grades = [];
  List<AuditLog> _currentAuditLogs = [];
  GradeLoadingState _loadingState = GradeLoadingState.idle;
  String? _errorMessage;
  bool _isVerifying = false;

  GradeProvider(this._api);

  // Getters
  List<GradeRecord> get grades => List.unmodifiable(_grades);
  List<AuditLog> get currentAuditLogs => _currentAuditLogs;
  GradeLoadingState get loadingState => _loadingState;
  String? get errorMessage => _errorMessage;
  bool get isVerifying => _isVerifying;
  bool get hasError => _loadingState == GradeLoadingState.error;
  bool get isLoading => _loadingState == GradeLoadingState.loading;

  List<GradeRecord> get verifiedGrades => _grades.where((g) => g.isVerified).toList();
  List<GradeRecord> get tamperedGrades => _grades.where((g) => !g.isVerified).toList();
  bool get hasTamperedGrades => tamperedGrades.isNotEmpty;

  double get gpa {
    final v = verifiedGrades;
    if (v.isEmpty) return 0.0;
    return v.map(_gradeToGpa).reduce((a, b) => a + b) / v.length;
  }

  double get averageGrade {
    final v = verifiedGrades;
    if (v.isEmpty) return 0.0;
    return v.map((g) => g.grade).reduce((a, b) => a + b) / v.length;
  }

  Map<String, int> get gradeDistribution {
    final map = {'A': 0, 'B': 0, 'C': 0, 'D': 0, 'F': 0};
    for (final g in _grades) {
      final letter = g.letterGrade.isNotEmpty ? g.letterGrade[0] : 'F';
      map.containsKey(letter) ? map[letter] = map[letter]! + 1 : map['F'] = map['F']! + 1;
    }
    return map;
  }

  double _gradeToGpa(GradeRecord g) {
    if (g.grade >= 90) return 4.0;
    if (g.grade >= 80) return 3.0;
    if (g.grade >= 70) return 2.0;
    if (g.grade >= 60) return 1.0;
    return 0.0;
  }

  Future<void> loadGrades() async {
    _loadingState = GradeLoadingState.loading;
    _errorMessage = null;
    notifyListeners();
    try {
      _grades = await _api.fetchMyGrades();
      _loadingState = GradeLoadingState.success;
      // Grades come pre-verified from the server; do a client-side batch
      // verify pass to update any that may have changed.
      await _verifyAll();
    } catch (e) {
      _loadingState = GradeLoadingState.error;
      _errorMessage = e.toString();
      _grades = [];
    } finally {
      notifyListeners();
    }
  }

  Future<void> _verifyAll() async {
    if (_grades.isEmpty) return;
    _isVerifying = true;
    notifyListeners();
    try {
      final ids = _grades.map((g) => g.id).toList();
      final results = await _api.verifyMultipleGrades(ids);
      final resultMap = {
        for (final r in results)
          if (r['grade_id'] != null) r['grade_id'].toString(): r,
      };
      _grades = _grades.map((grade) {
        final result = resultMap[grade.id];
        if (result == null) return grade.copyWith(isVerified: false, verificationError: 'No result');
        return grade.copyWith(
          isVerified: (result['is_valid'] ?? false) as bool,
          verificationError: result['error'] as String?,
        );
      }).toList();
    } catch (e) {
      debugPrint('_verifyAll error: $e');
    } finally {
      _isVerifying = false;
      notifyListeners();
    }
  }

  Future<void> loadAuditLogs(String gradeId) async {
    try {
      _currentAuditLogs = await _api.fetchMyGradeLogs(gradeId);
    } catch (e) {
      debugPrint('loadAuditLogs error: $e');
      _currentAuditLogs = [];
    }
    notifyListeners();
  }

  Future<void> refresh() => loadGrades();

  void clear() {
    _grades = [];
    _loadingState = GradeLoadingState.idle;
    _errorMessage = null;
    _isVerifying = false;
    notifyListeners();
  }
}