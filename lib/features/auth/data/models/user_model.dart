class UserModel {
  const UserModel({
    required this.id,
    required this.email,
    required this.name,
    this.avatarUrl,
    required this.authProvider,
    required this.emailVerified,
  });

  final String id;
  final String email;
  final String name;
  final String? avatarUrl;
  final String authProvider;
  final bool emailVerified;

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] as String,
        email: json['email'] as String,
        name: json['name'] as String,
        avatarUrl: json['avatarUrl'] as String?,
        authProvider: json['authProvider'] as String? ?? 'EMAIL',
        emailVerified: json['emailVerified'] as bool? ?? false,
      );
}
