import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/student.dart';
import '../services/api_service.dart';

enum AuthState { unknown, unauthenticated, authenticated }

class StudentAuthProvider extends ChangeNotifier {
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'student_jwt';
  static const _studentKey = 'student_json';

  final ApiService _api;

  AuthState _state = AuthState.unknown;
  Student? _student;
  String? _token;
  String? _error;

  StudentAuthProvider(this._api) {
    _restoreSession();
  }

  AuthState get authState => _state;
  Student? get student => _student;
  String? get token => _token;
  String? get error => _error;
  bool get isAuthenticated => _state == AuthState.authenticated;

  Future<void> _restoreSession() async {
    try {
      final token = await _storage.read(key: _tokenKey);
      final studentJson = await _storage.read(key: _studentKey);
      if (token != null && studentJson != null) {
        _token = token;
        _student = Student.fromJson(jsonDecode(studentJson));
        _api.authToken = token;
        _state = AuthState.authenticated;
      } else {
        _state = AuthState.unauthenticated;
      }
    } catch (_) {
      _state = AuthState.unauthenticated;
    }
    notifyListeners();
  }

  Future<bool> register({
    required String name,
    required String studentId,
    required String department,
    required String email,
    required String password,
  }) async {
    _error = null;
    notifyListeners();
    try {
      final result = await _api.studentRegister(
        name: name,
        studentId: studentId,
        department: department,
        email: email,
        password: password,
      );
      await _saveSession(result['access_token'], result['student']);
      return true;
    } catch (e) {
      _error = _friendlyError(e.toString());
      notifyListeners();
      return false;
    }
  }

  Future<bool> login({
    required String studentId,
    required String password,
  }) async {
    _error = null;
    notifyListeners();
    try {
      final result = await _api.studentLogin(
        studentId: studentId,
        password: password,
      );
      await _saveSession(result['access_token'], result['student']);
      return true;
    } catch (e) {
      _error = _friendlyError(e.toString());
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _studentKey);
    _api.authToken = null;
    _token = null;
    _student = null;
    _state = AuthState.unauthenticated;
    notifyListeners();
  }

  Future<void> _saveSession(String token, Map<String, dynamic> studentJson) async {
    _token = token;
    _student = Student.fromJson(studentJson);
    _api.authToken = token;
    _state = AuthState.authenticated;
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _studentKey, value: jsonEncode(studentJson));
    notifyListeners();
  }

  String _friendlyError(String raw) {
    if (raw.contains('Student ID already')) return 'That Student ID is already registered.';
    if (raw.contains('Email already')) return 'That email is already registered.';
    if (raw.contains('Invalid Student ID') || raw.contains('401')) {
      return 'Incorrect Student ID or password.';
    }
    if (raw.contains('SocketException') || raw.contains('Connection')) {
      return 'Cannot reach server — check your connection.';
    }
    return 'Something went wrong. Please try again.';
  }
}
