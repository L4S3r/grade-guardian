class Student {
  final String id;
  final String studentId;
  final String name;
  final String email;
  final String department;

  const Student({
    required this.id,
    required this.studentId,
    required this.name,
    required this.email,
    required this.department,
  });

  factory Student.fromJson(Map<String, dynamic> json) => Student(
        id: json['id'] as String,
        studentId: json['student_id'] as String,
        name: json['name'] as String,
        email: json['email'] as String,
        department: json['department'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'student_id': studentId,
        'name': name,
        'email': email,
        'department': department,
      };
}