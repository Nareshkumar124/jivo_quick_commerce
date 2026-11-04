// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/order_status_enum.dart';
import 'package:jivo_api/src/model/track_point.dart';
import 'package:jivo_api/src/model/track_rider.dart';
import 'package:jivo_api/src/model/track_store.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'order_track.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class OrderTrack {
  /// Returns a new [OrderTrack] instance.
  OrderTrack({
    required this.orderId,

    required this.orderNumber,

    required this.status,

    required this.etaAt,

    required this.store,

    required this.destination,

    required this.rider,

    required this.deliveryOtp,

    required this.serverTime,
  });

  @JsonKey(name: r'order_id', required: true, includeIfNull: false)
  final int orderId;

  /// e.g. \"JV-261110-001203\".
  @JsonKey(name: r'order_number', required: true, includeIfNull: false)
  final String orderNumber;

  @JsonKey(
    name: r'status',
    required: true,
    includeIfNull: false,
    unknownEnumValue: OrderStatusEnum.unknownDefaultOpenApi,
  )
  final OrderStatusEnum status;

  /// Promised delivery time (08 §8); null once the order ended.
  @JsonKey(name: r'eta_at', required: true, includeIfNull: true)
  final DateTime? etaAt;

  @JsonKey(name: r'store', required: true, includeIfNull: false)
  final TrackStore store;

  /// The delivery pin.
  @JsonKey(name: r'destination', required: true, includeIfNull: false)
  final TrackPoint destination;

  /// Null until a rider accepts, and again once the order is finished.
  @JsonKey(name: r'rider', required: true, includeIfNull: true)
  final TrackRider? rider;

  /// The 4-digit OTP to give the rider, only while OUT_FOR_DELIVERY; null otherwise. Never share it before the rider arrives.
  @JsonKey(name: r'delivery_otp', required: true, includeIfNull: true)
  final String? deliveryOtp;

  @JsonKey(name: r'server_time', required: true, includeIfNull: false)
  final DateTime serverTime;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrderTrack &&
          other.orderId == orderId &&
          other.orderNumber == orderNumber &&
          other.status == status &&
          other.etaAt == etaAt &&
          other.store == store &&
          other.destination == destination &&
          other.rider == rider &&
          other.deliveryOtp == deliveryOtp &&
          other.serverTime == serverTime;

  @override
  int get hashCode =>
      orderId.hashCode +
      orderNumber.hashCode +
      status.hashCode +
      (etaAt == null ? 0 : etaAt.hashCode) +
      store.hashCode +
      destination.hashCode +
      (rider == null ? 0 : rider.hashCode) +
      (deliveryOtp == null ? 0 : deliveryOtp.hashCode) +
      serverTime.hashCode;

  factory OrderTrack.fromJson(Map<String, dynamic> json) =>
      _$OrderTrackFromJson(json);

  Map<String, dynamic> toJson() => _$OrderTrackToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
