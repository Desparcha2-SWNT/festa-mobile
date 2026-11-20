import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/http_providers.dart';
import '../../auth/application/session_controller.dart';
import '../data/attendance_api.dart';
import '../domain/attendance_status.dart';

final attendanceApiProvider = Provider<AttendanceApi>((ref) => AttendanceApi(ref.watch(authenticatedDioProvider)));

/// Asistencia del usuario de la sesión a un evento. `autoDispose`: al salir del detalle se descarta, y al
/// volver se pide de nuevo, así se ven los cupos que ocuparon otros mientras tanto.
final attendanceControllerProvider = AsyncNotifierProvider.autoDispose
    .family<AttendanceController, AttendanceStatus, String>(AttendanceController.new, retry: retryAttendance);

/// Un 4xx no cambia reintentando; un error de red o del servidor se reintenta dos veces.
Duration? retryAttendance(int retryCount, Object error) {
  final status = error is ApiException ? error.statusCode : null;
  if (status != null && status >= 400 && status < 500) return null;
  if (retryCount >= 2) return null;
  return Duration(milliseconds: 300 * (retryCount + 1));
}

class AttendanceController extends AsyncNotifier<AttendanceStatus> {
  AttendanceController(this.eventId);

  final String eventId;

  @override
  Future<AttendanceStatus> build() {
    // Si cambia la cuenta en el mismo teléfono, se pide el estado de la nueva.
    ref.watch(sessionControllerProvider.select((session) => session.value?.id));
    return ref.watch(attendanceApiProvider).status(eventId);
  }

  /// Confirma que el usuario va. Lanza `ApiException` si booking lo rechaza (sin cupos, evento cerrado).
  Future<void> confirm() => _change(confirmed: true, call: (api) => api.confirm(eventId));

  /// Cancela la asistencia confirmada.
  Future<void> cancel() => _change(confirmed: false, call: (api) => api.cancel(eventId));

  Future<void> _change({required bool confirmed, required Future<int> Function(AttendanceApi) call}) async {
    final current = state.value;
    if (current == null) return;
    try {
      final count = await call(ref.read(attendanceApiProvider));
      if (!ref.mounted || !identical(state.value, current)) return; // otra carga ya trae el estado nuevo
      state = AsyncData(current.copyWith(confirmed: confirmed, attendeeCount: count));
    } on ApiException catch (e) {
      // Un 409 (se llenó o ya no admite cambios) o un 404 dejan el estado viejo: se pide de nuevo.
      if (ref.mounted && (e.statusCode == 409 || e.statusCode == 404)) ref.invalidateSelf();
      rethrow;
    }
  }
}
