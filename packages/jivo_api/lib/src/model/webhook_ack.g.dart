// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'webhook_ack.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$WebhookAckCWProxy {
  WebhookAck status(WebhookResultEnum status);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WebhookAck(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WebhookAck(...).copyWith(id: 12, name: "My name")
  /// ````
  WebhookAck call({WebhookResultEnum status});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfWebhookAck.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfWebhookAck.copyWith.fieldName(...)`
class _$WebhookAckCWProxyImpl implements _$WebhookAckCWProxy {
  const _$WebhookAckCWProxyImpl(this._value);

  final WebhookAck _value;

  @override
  WebhookAck status(WebhookResultEnum status) => this(status: status);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WebhookAck(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WebhookAck(...).copyWith(id: 12, name: "My name")
  /// ````
  WebhookAck call({Object? status = const $CopyWithPlaceholder()}) {
    return WebhookAck(
      status: status == const $CopyWithPlaceholder()
          ? _value.status
          // ignore: cast_nullable_to_non_nullable
          : status as WebhookResultEnum,
    );
  }
}

extension $WebhookAckCopyWith on WebhookAck {
  /// Returns a callable class that can be used as follows: `instanceOfWebhookAck.copyWith(...)` or like so:`instanceOfWebhookAck.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$WebhookAckCWProxy get copyWith => _$WebhookAckCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WebhookAck _$WebhookAckFromJson(Map<String, dynamic> json) =>
    $checkedCreate('WebhookAck', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['status']);
      final val = WebhookAck(
        status: $checkedConvert(
          'status',
          (v) => $enumDecode(
            _$WebhookResultEnumEnumMap,
            v,
            unknownValue: WebhookResultEnum.unknownDefaultOpenApi,
          ),
        ),
      );
      return val;
    });

Map<String, dynamic> _$WebhookAckToJson(WebhookAck instance) =>
    <String, dynamic>{'status': _$WebhookResultEnumEnumMap[instance.status]!};

const _$WebhookResultEnumEnumMap = {
  WebhookResultEnum.processed: 'processed',
  WebhookResultEnum.duplicate: 'duplicate',
  WebhookResultEnum.ignored: 'ignored',
  WebhookResultEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
