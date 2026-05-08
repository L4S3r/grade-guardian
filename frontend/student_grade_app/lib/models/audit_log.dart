class AuditLog {
  final int? id;
  final String action;
  final String status;
  final DateTime checkedAt;
  final String? details;

  String? get errorDetails => details;

  AuditLog({
    this.id,
    required this.action,
    required this.status,
    required this.checkedAt,
    this.details,
  });

  factory AuditLog.fromJson(Map<String, dynamic> json) => AuditLog(
        id: json['id'],
        action: json['action'] ?? 'Unknown',
        status: json['status'] ?? 'UNKNOWN',
        checkedAt: DateTime.parse(json['checked_at']),
        details: json['details'],
      );
}