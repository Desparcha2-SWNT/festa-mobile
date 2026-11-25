import '../../reports/domain/report.dart';

/// Un reporte abierto que espera la revisión manual del equipo Festa (RF14, SCRUM-110), como lo devuelve
/// `GET /api/users/admin/reports` (`ReportResponse` en user-service).
class TeamReport {
  const TeamReport({
    required this.reportId,
    required this.target,
    required this.targetId,
    required this.reason,
    this.comment,
    this.reporterId,
    this.createdAt,
  });

  factory TeamReport.fromJson(Map<String, dynamic> json) => TeamReport(
    reportId: json['reportId'] as String,
    target: ReportTarget.fromApi(json['targetType'] as String?),
    targetId: json['targetId'] as String,
    reason: ReportReason.fromApi(json['reason'] as String?),
    comment: json['comment'] as String?,
    reporterId: json['reporterId'] as String?,
    createdAt: json['createdAt'] is String ? DateTime.parse(json['createdAt'] as String) : null,
  );

  final String reportId;
  final ReportTarget target;

  /// El evento o la cuenta reportados.
  final String targetId;
  final ReportReason reason;
  final String? comment;
  final String? reporterId;
  final DateTime? createdAt;
}

/// La cuenta reportada, según auth-service (`GET /api/auth/admin/accounts/{id}`, solo admin).
class ReportedAccount {
  const ReportedAccount({required this.id, required this.displayName, required this.email, required this.suspended});

  factory ReportedAccount.fromJson(Map<String, dynamic> json) => ReportedAccount(
    id: json['id'] as String,
    displayName: json['displayName'] as String? ?? '',
    email: json['email'] as String? ?? '',
    // auth-service manda el estado en minúscula: `active`, `suspended` o `deleted`.
    suspended: json['status'] == 'suspended',
  );

  final String id;
  final String displayName;
  final String email;
  final bool suspended;
}
