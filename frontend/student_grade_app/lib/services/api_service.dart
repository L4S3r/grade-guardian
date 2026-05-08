import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/grade_record.dart';
import '../models/audit_log.dart';

class ApiService {
  final String baseUrl;
  String? authToken;

  ApiService({required this.baseUrl});

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (authToken != null) 'Authorization': 'Bearer $authToken',
      };

  // ── Student Auth ───────────────────────────────────────────────────────
  Future<Map<String, dynamic>> studentRegister({
    required String name,
    required String studentId,
    required String department,
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/student/register'),
      headers: _headers,
      body: jsonEncode({
        'name': name,
        'student_id': studentId,
        'department': department,
        'email': email,
        'password': password,
      }),
    );
    if (response.statusCode == 201 || response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception(_extractDetail(response.body));
  }

  Future<Map<String, dynamic>> studentLogin({
    required String studentId,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/student/login'),
      headers: _headers,
      body: jsonEncode({'student_id': studentId, 'password': password}),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception(_extractDetail(response.body));
  }

  // ── Student Grades ─────────────────────────────────────────────────────
  Future<List<GradeRecord>> fetchMyGrades() async {
    final response = await http.get(
      Uri.parse('$baseUrl/student/grades'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      final List<dynamic> body = jsonDecode(response.body);
      return body.map((item) => GradeRecord.fromJson(item)).toList();
    }
    throw Exception('Failed to load grades: ${response.statusCode}');
  }

  Future<List<AuditLog>> fetchMyGradeLogs(String gradeId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/student/grades/$gradeId/logs'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List<dynamic> logsJson = data['logs'] ?? [];
      return logsJson.map((l) => AuditLog.fromJson(l)).toList();
    }
    throw Exception('Failed to load audit logs');
  }

  Future<List<Map<String, dynamic>>> verifyMultipleGrades(List<String> ids) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/verify/batch'),
        headers: _headers,
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
      debugPrint('verifyMultipleGrades error: $e');
      return [];
    }
  }

  String _extractDetail(String body) {
    try {
      final map = jsonDecode(body);
      return map['detail'] ?? body;
    } catch (_) {
      return body;
    }
  }
}

/// Endpoint configuration
class ApiConfig {
  static const String productionUrl = 'https://your-backend.onrender.com';
  static const String developmentUrl = 'http://10.0.2.2:8000';  // Android emulator

  static String get apiUrl =>
      kReleaseMode ? productionUrl : developmentUrl;
}