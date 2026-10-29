enum AccountType {
  user('user'),
  merchant('merchant');

  const AccountType(this.apiValue);

  final String apiValue;
}

enum Role {
  user,
  merchant,
  admin;

  static Role fromApi(String value) => Role.values.firstWhere((r) => r.name == value, orElse: () => Role.user);
}

/// Cuenta autenticada, tal como la devuelve auth-service.
class Account {
  const Account({required this.id, required this.email, required this.displayName, required this.role});

  factory Account.fromJson(Map<String, dynamic> json) => Account(
    id: json['id'] as String,
    email: json['email'] as String,
    displayName: json['displayName'] as String,
    role: Role.fromApi(json['role'] as String),
  );

  final String id;
  final String email;
  final String displayName;
  final Role role;
}
