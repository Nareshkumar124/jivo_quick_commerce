// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'razorpay_webhook_event_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class RazorpayWebhookEventRequest {
  /// Returns a new [RazorpayWebhookEventRequest] instance.
  RazorpayWebhookEventRequest({
    this.entity,

    this.accountId,

    required this.event,

    this.contains,

    required this.payload,

    this.createdAt,
  });

  /// \"event\".
  @JsonKey(name: r'entity', required: false, includeIfNull: false)
  final String? entity;

  @JsonKey(name: r'account_id', required: false, includeIfNull: false)
  final String? accountId;

  /// Handled: `payment.captured`, `payment.failed`, `refund.processed`, `refund.failed`. Others are acknowledged and ignored.
  @JsonKey(name: r'event', required: true, includeIfNull: false)
  final String event;

  @JsonKey(name: r'contains', required: false, includeIfNull: false)
  final List<String>? contains;

  /// The entities, e.g. `payment.entity`.
  @JsonKey(name: r'payload', required: true, includeIfNull: false)
  final Map<String, Object> payload;

  /// Unix time.
  @JsonKey(name: r'created_at', required: false, includeIfNull: false)
  final int? createdAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RazorpayWebhookEventRequest &&
          other.entity == entity &&
          other.accountId == accountId &&
          other.event == event &&
          other.contains == contains &&
          other.payload == payload &&
          other.createdAt == createdAt;

  @override
  int get hashCode =>
      entity.hashCode +
      accountId.hashCode +
      event.hashCode +
      contains.hashCode +
      payload.hashCode +
      createdAt.hashCode;

  factory RazorpayWebhookEventRequest.fromJson(Map<String, dynamic> json) =>
      _$RazorpayWebhookEventRequestFromJson(json);

  Map<String, dynamic> toJson() => _$RazorpayWebhookEventRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
