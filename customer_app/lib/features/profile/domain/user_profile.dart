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
    this.hasPhone = true,
    this.emailVerified = false,
  });

  final int id;

  /// `+91…`. Not editable in v1. Empty for an email sign-up that has not
  /// added a phone ([hasPhone] false).
  final String phone;
  final String name;
  final String? email;

  /// False until a name is set: show the complete-profile screen.
  final bool isProfileComplete;

  /// False for an email sign-up that has not added a phone yet.
  final bool hasPhone;

  /// The email was proved with an OTP (email sign-in or `me/email/verify/`).
  final bool emailVerified;

  /// The verified email is this account's only sign-in: it can't be
  /// changed or cleared through the profile form.
  bool get emailLocked => !hasPhone && emailVerified;

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
    hasPhone: hasPhone,
    emailVerified: emailVerified,
  );

  @override
  bool operator ==(Object other) =>
      other is UserProfile &&
      other.id == id &&
      other.phone == phone &&
      other.name == name &&
      other.email == email &&
      other.isProfileComplete == isProfileComplete &&
      other.hasPhone == hasPhone &&
      other.emailVerified == emailVerified;

  @override
  int get hashCode => Object.hash(
    id,
    phone,
    name,
    email,
    isProfileComplete,
    hasPhone,
    emailVerified,
  );
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
