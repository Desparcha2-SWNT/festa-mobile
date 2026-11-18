abstract final class Routes {
  static const splash = '/splash';
  static const login = '/login';
  static const register = '/register';
  static const home = '/';
  static const merchantPending = '/merchant/pending';

  /// Lista de asistentes de un evento, para su organizador (SCRUM-141).
  static const eventAttendees = '/events/:id/attendees';
  static String attendeesOf(String eventId) => '/events/$eventId/attendees';
}
