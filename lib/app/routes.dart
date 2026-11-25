abstract final class Routes {
  static const splash = '/splash';
  static const login = '/login';
  static const register = '/register';
  static const locationConsent = '/location-consent';
  static const home = '/';
  static const map = '/map';
  static const eventDetailPattern = '/events/:id';
  static const myEvents = '/my-events';
  static const createEvent = '/my-events/new';
  static const editEventPattern = '/my-events/:id/edit';
  static const myMerchant = '/merchant';
  static const merchantForm = '/merchant/form';
  static const merchantStatus = '/merchant/status';
  static const profile = '/profile';
  static const plans = '/plans';
  static const passes = '/passes';

  /// Chat de recomendaciones con la IA (RF8).
  static const chat = '/chat';

  /// Lista de asistentes de un evento, para su organizador (SCRUM-141).
  static const eventAttendees = '/events/:id/attendees';

  /// Escáner de QR en la puerta de un evento, para su organizador (SCRUM-92).
  static const eventCheckIn = '/events/:id/check-in';

  static String eventDetail(String id) => '/events/$id';

  static String editEvent(String id) => '/my-events/$id/edit';

  static String attendeesOf(String eventId) => '/events/$eventId/attendees';

  static String checkInOf(String eventId) => '/events/$eventId/check-in';
}
