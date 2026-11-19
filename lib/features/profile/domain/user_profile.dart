/// Intereses de plan (RF2). Los mismos valores que `Interest` en festa-user-service y las categorías de evento.
enum Interest {
  cultural('Cultural'),
  musical('Musical'),
  deportivo('Deportivo'),
  gastronomico('Gastronómico');

  const Interest(this.label);

  final String label;

  /// Valor que viaja a la API (`CULTURAL`, `MUSICAL`, ...).
  String get apiValue => name.toUpperCase();

  static Interest? fromApi(String value) {
    for (final interest in Interest.values) {
      if (interest.apiValue == value.toUpperCase()) return interest;
    }
    return null;
  }
}

/// Presupuesto por plan (`BudgetRange` en festa-user-service).
enum BudgetRange {
  any('Cualquiera', 'ANY'),
  low('Bajo', 'LOW'),
  medium('Medio', 'MEDIUM'),
  high('Alto', 'HIGH');

  const BudgetRange(this.label, this.apiValue);

  final String label;
  final String apiValue;

  static BudgetRange fromApi(String? value) =>
      BudgetRange.values.firstWhere((b) => b.apiValue == value?.toUpperCase(), orElse: () => BudgetRange.any);
}

/// Preferencias de recomendación. Solo lo que muestra el Figma: presupuesto y distancia máxima.
class UserPreferences {
  const UserPreferences({this.budgetRange = BudgetRange.any, this.maxDistanceKm = defaultMaxDistanceKm});

  factory UserPreferences.fromJson(Map<String, dynamic> json) => UserPreferences(
    budgetRange: BudgetRange.fromApi(json['budgetRange'] as String?),
    maxDistanceKm: (json['maxDistanceKm'] as num?)?.toInt() ?? defaultMaxDistanceKm,
  );

  static const defaultMaxDistanceKm = 5;

  final BudgetRange budgetRange;
  final int maxDistanceKm;

  UserPreferences copyWith({BudgetRange? budgetRange, int? maxDistanceKm}) =>
      UserPreferences(budgetRange: budgetRange ?? this.budgetRange, maxDistanceKm: maxDistanceKm ?? this.maxDistanceKm);

  @override
  bool operator ==(Object other) =>
      other is UserPreferences && other.budgetRange == budgetRange && other.maxDistanceKm == maxDistanceKm;

  @override
  int get hashCode => Object.hash(budgetRange, maxDistanceKm);
}

/// Intereses y preferencias del usuario (respuesta de `GET /users/me`).
class UserProfile {
  const UserProfile({this.interests = const {}, this.preferences = const UserPreferences()});

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final interests = <Interest>{
      for (final value in (json['interests'] as List<dynamic>? ?? const [])) ?Interest.fromApi(value as String),
    };
    final preferences = json['preferences'];
    return UserProfile(
      interests: interests,
      preferences: preferences is Map<String, dynamic>
          ? UserPreferences.fromJson(preferences)
          : const UserPreferences(),
    );
  }

  final Set<Interest> interests;
  final UserPreferences preferences;
}
