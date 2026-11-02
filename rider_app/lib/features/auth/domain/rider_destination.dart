import 'package:jivo_api/jivo_api.dart' show RiderStatusEnum;

/// Where a signed-in rider lands, by `rider_status` (04 §1 journey).
enum RiderDestination {
  /// `NONE`: no rider profile yet. The registration form.
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

/// Whether the rider can still change their application (upload or replace
/// documents, bank details): while it is in review or after a rejection.
bool canEditApplication(RiderStatusEnum status) =>
    status == RiderStatusEnum.PENDING_KYC || status == RiderStatusEnum.REJECTED;
