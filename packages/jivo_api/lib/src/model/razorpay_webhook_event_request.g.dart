// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'razorpay_webhook_event_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$RazorpayWebhookEventRequestCWProxy {
  RazorpayWebhookEventRequest entity(String? entity);

  RazorpayWebhookEventRequest accountId(String? accountId);

  RazorpayWebhookEventRequest event(String event);

  RazorpayWebhookEventRequest contains(List<String>? contains);

  RazorpayWebhookEventRequest payload(Map<String, Object> payload);

  RazorpayWebhookEventRequest createdAt(int? createdAt);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RazorpayWebhookEventRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RazorpayWebhookEventRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  RazorpayWebhookEventRequest call({
    String? entity,
    String? accountId,
    String event,
    List<String>? contains,
    Map<String, Object> payload,
    int? createdAt,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfRazorpayWebhookEventRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfRazorpayWebhookEventRequest.copyWith.fieldName(...)`
class _$RazorpayWebhookEventRequestCWProxyImpl
    implements _$RazorpayWebhookEventRequestCWProxy {
  const _$RazorpayWebhookEventRequestCWProxyImpl(this._value);

  final RazorpayWebhookEventRequest _value;

  @override
  RazorpayWebhookEventRequest entity(String? entity) => this(entity: entity);

  @override
  RazorpayWebhookEventRequest accountId(String? accountId) =>
      this(accountId: accountId);

  @override
  RazorpayWebhookEventRequest event(String event) => this(event: event);

  @override
  RazorpayWebhookEventRequest contains(List<String>? contains) =>
      this(contains: contains);

  @override
  RazorpayWebhookEventRequest payload(Map<String, Object> payload) =>
      this(payload: payload);

  @override
  RazorpayWebhookEventRequest createdAt(int? createdAt) =>
      this(createdAt: createdAt);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RazorpayWebhookEventRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RazorpayWebhookEventRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  RazorpayWebhookEventRequest call({
    Object? entity = const $CopyWithPlaceholder(),
    Object? accountId = const $CopyWithPlaceholder(),
    Object? event = const $CopyWithPlaceholder(),
    Object? contains = const $CopyWithPlaceholder(),
    Object? payload = const $CopyWithPlaceholder(),
    Object? createdAt = const $CopyWithPlaceholder(),
  }) {
    return RazorpayWebhookEventRequest(
      entity: entity == const $CopyWithPlaceholder()
          ? _value.entity
          // ignore: cast_nullable_to_non_nullable
          : entity as String?,
      accountId: accountId == const $CopyWithPlaceholder()
          ? _value.accountId
          // ignore: cast_nullable_to_non_nullable
          : accountId as String?,
      event: event == const $CopyWithPlaceholder()
          ? _value.event
          // ignore: cast_nullable_to_non_nullable
          : event as String,
      contains: contains == const $CopyWithPlaceholder()
          ? _value.contains
          // ignore: cast_nullable_to_non_nullable
          : contains as List<String>?,
      payload: payload == const $CopyWithPlaceholder()
          ? _value.payload
          // ignore: cast_nullable_to_non_nullable
          : payload as Map<String, Object>,
      createdAt: createdAt == const $CopyWithPlaceholder()
          ? _value.createdAt
          // ignore: cast_nullable_to_non_nullable
          : createdAt as int?,
    );
  }
}

extension $RazorpayWebhookEventRequestCopyWith on RazorpayWebhookEventRequest {
  /// Returns a callable class that can be used as follows: `instanceOfRazorpayWebhookEventRequest.copyWith(...)` or like so:`instanceOfRazorpayWebhookEventRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$RazorpayWebhookEventRequestCWProxy get copyWith =>
      _$RazorpayWebhookEventRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RazorpayWebhookEventRequest _$RazorpayWebhookEventRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('RazorpayWebhookEventRequest', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['event', 'payload']);
  final val = RazorpayWebhookEventRequest(
    entity: $checkedConvert('entity', (v) => v as String?),
    accountId: $checkedConvert('account_id', (v) => v as String?),
    event: $checkedConvert('event', (v) => v as String),
    contains: $checkedConvert(
      'contains',
      (v) => (v as List<dynamic>?)?.map((e) => e as String).toList(),
    ),
    payload: $checkedConvert(
      'payload',
      (v) =>
          (v as Map<String, dynamic>).map((k, e) => MapEntry(k, e as Object)),
    ),
    createdAt: $checkedConvert('created_at', (v) => (v as num?)?.toInt()),
  );
  return val;
}, fieldKeyMap: const {'accountId': 'account_id', 'createdAt': 'created_at'});

Map<String, dynamic> _$RazorpayWebhookEventRequestToJson(
  RazorpayWebhookEventRequest instance,
) => <String, dynamic>{
  'entity': ?instance.entity,
  'account_id': ?instance.accountId,
  'event': instance.event,
  'contains': ?instance.contains,
  'payload': instance.payload,
  'created_at': ?instance.createdAt,
};
