import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/grade_record.dart';
import '../models/audit_log.dart';

class ApiService {
  final String baseUrl = 'https://grade-guardian.onrender.com';

  ApiService({required baseUrl});

  // 1. Fetching grades
  Future<List<GradeRecord>> fetchGrades({String? studentId}) async {
    String url = '$baseUrl/grades';
    if (studentId != null) url += '?student_id=$studentId';

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body);
      return body.map((dynamic item) => GradeRecord.fromJson(item)).toList();
    }
    throw Exception('Failed to load grades');
  }

  // 2. Submit a new grade
  Future<GradeRecord> submitGrade({
    required String studentId,
    required String courseName,
    required String courseCode,
    required double grade,
    required String letterGrade,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/grades'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'student_id': studentId,
        'course_name': courseName,
        'course_code': courseCode,
        'grade': grade,
        'letter_grade': letterGrade,
      }),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      return GradeRecord.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to submit grade: ${response.body}');
  }

  // 3. Verify a single grade (integrity check only, no logs)
  Future<Map<String, dynamic>> verifyGrade(String gradeId) async {
    final results = await verifyMultipleGrades([gradeId]);

    if (results.isNotEmpty) {
    return {
      'is_valid': results.first['is_valid'] ?? false,
      'error': results.first['error'],
    };
  }
  return {'is_valid': false, 'error': 'Grade not found'};
}
  // 4. Fetch audit logs for a specific grade
  Future<List<AuditLog>> fetchGradeLogs(String gradeId) async {
    final response = await http.get(Uri.parse('$baseUrl/grades/$gradeId/logs'));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List<dynamic> logsJson = data['logs'] ?? [];
      return logsJson.map((l) => AuditLog.fromJson(l)).toList();
    }
    throw Exception('Failed to load audit logs');
  }

  // 5. Verify multiple grades in batch
  Future<List<Map<String, dynamic>>> verifyMultipleGrades(List<String> ids) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/verify/batch'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'grade_ids': ids}),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) return List<Map<String, dynamic>>.from(decoded);
        if (decoded is Map && decoded.containsKey('results')) {
          return List<Map<String, dynamic>>.from(decoded['results']);
        }
      }
      return [];
    } catch (e) {
      debugPrint("Service Error: $e");
      return [];
    }
  }

  // 6. Fetch all audit logs (for the audit log screen)
  Future<List<AuditLog>> fetchAuditLogs() async {
    final response = await http.get(Uri.parse('$baseUrl/audit-logs'));
    if (response.statusCode == 200) {
      final List<dynamic> logsJson = jsonDecode(response.body);
      return logsJson.map((l) => AuditLog.fromJson(l)).toList();
    }
    throw Exception('Failed to load audit logs');
  }
}