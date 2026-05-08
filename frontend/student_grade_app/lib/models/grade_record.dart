import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

class GradeRecord extends Equatable {
  final String id;
  final String studentId;
  final String courseName;
  final String courseCode;
  final double grade;
  final String letterGrade;
  final DateTime recordedAt;
  final String hash;
  final bool isVerified;
  final String? verificationError;

  const GradeRecord({
    required this.id,
    required this.studentId,
    required this.courseName,
    required this.courseCode,
    required this.grade,
    required this.letterGrade,
    required this.recordedAt,
    required this.hash,
    this.isVerified = false,
    this.verificationError,
  });

  factory GradeRecord.fromJson(Map<String, dynamic> json) {
    try {
      return GradeRecord(
        id: json['id'].toString(),
        studentId: json['student_id'] ?? 'N/A',
        courseName: json['course_name'] ?? 'N/A',
        courseCode: json['course_code'] ?? 'N/A',
        grade: (json['grade'] as num?)?.toDouble() ?? 0.0,
        letterGrade: json['letter_grade'] ?? 'F',
        recordedAt: json['recorded_at'] != null
            ? DateTime.parse(json['recorded_at'])
            : DateTime.now(),
        hash: json['hash'] ?? '',
        isVerified: json['is_verified'] ?? false,
        verificationError: json['verification_error'],
      );
    } catch (e) {
      debugPrint('GradeRecord.fromJson error: $e  |  json: $json');
      rethrow;
    }
  }

  GradeRecord copyWith({
    String? id,
    String? studentId,
    String? courseName,
    String? courseCode,
    double? grade,
    String? letterGrade,
    DateTime? recordedAt,
    String? hash,
    bool? isVerified,
    String? verificationError,
  }) =>
      GradeRecord(
        id: id ?? this.id,
        studentId: studentId ?? this.studentId,
        courseName: courseName ?? this.courseName,
        courseCode: courseCode ?? this.courseCode,
        grade: grade ?? this.grade,
        letterGrade: letterGrade ?? this.letterGrade,
        recordedAt: recordedAt ?? this.recordedAt,
        hash: hash ?? this.hash,
        isVerified: isVerified ?? this.isVerified,
        verificationError: verificationError ?? this.verificationError,
      );

  @override
  List<Object?> get props => [
        id, studentId, courseName, courseCode, grade, letterGrade,
        recordedAt, hash, isVerified, verificationError,
      ];
}