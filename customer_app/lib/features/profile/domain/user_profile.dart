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
    this.businessCategoryId,
    this.businessCategoryName,
    this.businessName = '',
  });

  final int id;

  /// `+91…`. Not editable in v1.
  final String phone;

  /// Empty after the complete-profile screen was skipped: show
  /// [displayName]-style fallbacks, never a blank.
  final String name;
  final String? email;

  /// False only for a new user who has neither submitted nor skipped the
  /// complete-profile screen (`03 §2.2`): show that screen while false.
  final bool isProfileComplete;

  /// An id from `GET /business-categories/`, or null.
  final int? businessCategoryId;

  /// The chosen category's name, for display.
  final String? businessCategoryName;

  /// Shop / business name; empty when not given.
  final String businessName;

  /// True when the user has a non-blank name.
  bool get hasName => name.trim().isNotEmpty;

  UserProfile copyWith({
    String? name,
    String? email,
    bool? isProfileComplete,
    int? businessCategoryId,
    String? businessCategoryName,
    String? businessName,
  }) => UserProfile(
    id: id,
    phone: phone,
    name: name ?? this.name,
    email: email ?? this.email,
    isProfileComplete: isProfileComplete ?? this.isProfileComplete,
    businessCategoryId: businessCategoryId ?? this.businessCategoryId,
    businessCategoryName: businessCategoryName ?? this.businessCategoryName,
    businessName: businessName ?? this.businessName,
  );

  @override
  bool operator ==(Object other) =>
      other is UserProfile &&
      other.id == id &&
      other.phone == phone &&
      other.name == name &&
      other.email == email &&
      other.isProfileComplete == isProfileComplete &&
      other.businessCategoryId == businessCategoryId &&
      other.businessCategoryName == businessCategoryName &&
      other.businessName == businessName;

  @override
  int get hashCode => Object.hash(
    id,
    phone,
    name,
    email,
    isProfileComplete,
    businessCategoryId,
    businessCategoryName,
    businessName,
  );
}

/// One entry of `GET /business-categories/` (the complete-profile dropdown).
@immutable
class BusinessCategory {
  const BusinessCategory({
    required this.id,
    required this.name,
    required this.slug,
  });

  final int id;
  final String name;
  final String slug;

  @override
  bool operator ==(Object other) =>
      other is BusinessCategory &&
      other.id == id &&
      other.name == name &&
      other.slug == slug;

  @override
  int get hashCode => Object.hash(id, name, slug);
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
