import 'package:flutter/foundation.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../profile/domain/user_profile.dart';

enum OtpPurpose { login, deleteAccount }

/// An OTP has been sent (`POST /api/v1/auth/otp/request/`).
@immutable
class OtpChallenge {
  const OtpChallenge({
    required this.phone,
    required this.otpLength,
    required this.resendAfterSeconds,
    required this.expiresInSeconds,
  });

  /// `+91…`
  final String phone;
  final int otpLength;
  final int resendAfterSeconds;
  final int expiresInSeconds;
}

/// A successful `POST /api/v1/auth/otp/verify/`.
@immutable
class SignInResult {
  const SignInResult({
    required this.tokens,
    required this.user,
    required this.isNewUser,
    required this.deletionCancelled,
  });

  final AuthTokens tokens;
  final UserProfile user;
  final bool isNewUser;

  /// This login restored an account inside its deletion grace period.
  final bool deletionCancelled;

  /// `03 §2.2`: new users and incomplete profiles go to complete-profile.
  bool get needsProfile => isNewUser || !user.isProfileComplete;
}
