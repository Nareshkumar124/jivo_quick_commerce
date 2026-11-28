import 'package:flutter/foundation.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../profile/domain/user_profile.dart';

enum OtpPurpose { login, deleteAccount }

/// How a customer signs in (`GET /auth/methods/`): an SMS OTP to the phone
/// or an email OTP. Also the channel an OTP was sent over.
enum LoginMethod { phone, email }

/// An OTP has been sent (`POST /auth/otp/request/`,
/// `/auth/email-otp/request/`, `/me/phone/otp/`, `/me/email/otp/`).
@immutable
class OtpChallenge {
  const OtpChallenge({
    required this.destination,
    required this.otpLength,
    required this.resendAfterSeconds,
    required this.expiresInSeconds,
    this.method = LoginMethod.phone,
  });

  /// Where the OTP went: `+91…` for [LoginMethod.phone], the email address
  /// for [LoginMethod.email].
  final String destination;
  final LoginMethod method;
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
