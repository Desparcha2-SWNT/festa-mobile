abstract final class Routes {
  static const splash = '/splash';
  static const login = '/login';
  static const register = '/register';
  static const locationConsent = '/location-consent';
  static const home = '/';
  static const map = '/map';
  static const eventDetailPattern = '/events/:id';
  static const myMerchant = '/merchant';
  static const merchantForm = '/merchant/form';
  static const merchantStatus = '/merchant/status';

  static String eventDetail(String id) => '/events/$id';
}
