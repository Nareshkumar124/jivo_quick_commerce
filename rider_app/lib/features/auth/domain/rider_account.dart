import 'package:jivo_api/jivo_api.dart' show Me, RiderStatusEnum;
import 'package:jivo_core/jivo_core.dart';

/// The signed-in user's account as the rider app needs it: who they are and
/// their `rider_status`. Separate from jivo_core's session (which only knows
/// whether tokens exist).
sealed class RiderAccountState {
  const RiderAccountState();
}

/// Not loaded (signed out, or signed in but `GET /me/` not done yet).
final class AccountUnknown extends RiderAccountState {
  const AccountUnknown();
}

/// `GET /me/` failed without ending the session (no network, timeout, 5xx).
/// The tokens are kept; the splash offers Retry.
final class AccountLoadFailed extends RiderAccountState {
  const AccountLoadFailed(this.error);

  final ApiError error;
}

final class AccountLoaded extends RiderAccountState {
  const AccountLoaded({required this.user, required this.riderStatus});

  final Me user;
  final RiderStatusEnum riderStatus;
}
