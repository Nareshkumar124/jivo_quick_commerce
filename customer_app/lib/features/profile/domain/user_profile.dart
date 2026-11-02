import 'package:flutter/foundation.dart';

/// The signed-in user (`GET /api/v1/me/`).
@immutable
class UserProfile {
  const UserProfile({
    required this.id,
    required this.phone,
    required this.name,
    required this.isProfileComplete,
    this.email,
  });

  final int id;

  /// `+91…`. Not editable in v1.
  final String phone;
  final String name;
  final String? email;

  /// False until a name is set: show the complete-profile screen.
  final bool isProfileComplete;

  UserProfile copyWith({
    String? name,
    String? email,
    bool? isProfileComplete,
  }) => UserProfile(
    id: id,
    phone: phone,
    name: name ?? this.name,
    email: email ?? this.email,
    isProfileComplete: isProfileComplete ?? this.isProfileComplete,
  );

  @override
  bool operator ==(Object other) =>
      other is UserProfile &&
      other.id == id &&
      other.phone == phone &&
      other.name == name &&
      other.email == email &&
      other.isProfileComplete == isProfileComplete;

  @override
  int get hashCode => Object.hash(id, phone, name, email, isProfileComplete);
}

/// Result of `POST /api/v1/me/delete/`.
@immutable
class AccountDeletion {
  const AccountDeletion({
    required this.deletedAt,
    required this.anonymiseAfter,
  });

  final DateTime deletedAt;

  /// Logging in before this restores the account.
  final DateTime anonymiseAfter;
}
