import 'package:jivo_api/jivo_api.dart' show RiderStatusEnum;

/// Where a signed-in rider lands, by `rider_status` (04 §1 journey).
enum RiderDestination {
  /// `NONE`: no rider profile yet. Registration placeholder (P5).
  register,

  /// `PENDING_KYC`, `REJECTED`, `SUSPENDED`, or a value this app version does
  /// not know: a status screen. Never home.
  status,

  /// `ACTIVE`: home (go online, offers).
  home,
}

RiderDestination destinationFor(RiderStatusEnum status) => switch (status) {
  RiderStatusEnum.NONE => RiderDestination.register,
  RiderStatusEnum.ACTIVE => RiderDestination.home,
  RiderStatusEnum.PENDING_KYC ||
  RiderStatusEnum.REJECTED ||
  RiderStatusEnum.SUSPENDED ||
  RiderStatusEnum.unknownDefaultOpenApi => RiderDestination.status,
};
