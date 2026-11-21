/// Asistencia del usuario a un evento gratis, con los cupos ocupados (`GET .../attendance`).
class AttendanceStatus {
  const AttendanceStatus({required this.confirmed, required this.attendeeCount, this.capacity});

  factory AttendanceStatus.fromJson(Map<String, dynamic> json) => AttendanceStatus(
    confirmed: json['confirmed'] as bool? ?? false,
    attendeeCount: json['attendeeCount'] as int? ?? 0,
    capacity: json['capacity'] as int?,
  );

  final bool confirmed;
  final int attendeeCount;

  /// `null` si el evento no tiene cupo máximo.
  final int? capacity;

  /// Lleno para quien todavía no confirmó: quien ya tiene su cupo lo conserva.
  bool get full => !confirmed && capacity != null && attendeeCount >= capacity!;

  AttendanceStatus copyWith({bool? confirmed, int? attendeeCount}) => AttendanceStatus(
    confirmed: confirmed ?? this.confirmed,
    attendeeCount: attendeeCount ?? this.attendeeCount,
    capacity: capacity,
  );
}
