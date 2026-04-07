enum UserRole { client, driver }
enum UserStatus { idle, searching, onTrip }

class AppUser {
  final String id; // UUID
  final UserRole role;
  final UserStatus status;

  AppUser({
    required this.id,
    required this.role,
    required this.status,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'role': role.name,
    'status': status.name,
  };

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: json['id'],
    role: UserRole.values.byName(json['role']),
    status: UserStatus.values.byName(json['status']),
  );
}
