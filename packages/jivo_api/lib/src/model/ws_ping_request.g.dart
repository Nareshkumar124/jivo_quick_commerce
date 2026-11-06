// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ws_ping_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$WsPingRequestCWProxy {
  WsPingRequest type(String type);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WsPingRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WsPingRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  WsPingRequest call({String type});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfWsPingRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfWsPingRequest.copyWith.fieldName(...)`
class _$WsPingRequestCWProxyImpl implements _$WsPingRequestCWProxy {
  const _$WsPingRequestCWProxyImpl(this._value);

  final WsPingRequest _value;

  @override
  WsPingRequest type(String type) => this(type: type);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WsPingRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WsPingRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  WsPingRequest call({Object? type = const $CopyWithPlaceholder()}) {
    return WsPingRequest(
      type: type == const $CopyWithPlaceholder()
          ? _value.type
          // ignore: cast_nullable_to_non_nullable
          : type as String,
    );
  }
}

extension $WsPingRequestCopyWith on WsPingRequest {
  /// Returns a callable class that can be used as follows: `instanceOfWsPingRequest.copyWith(...)` or like so:`instanceOfWsPingRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$WsPingRequestCWProxy get copyWith => _$WsPingRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WsPingRequest _$WsPingRequestFromJson(Map<String, dynamic> json) =>
    $checkedCreate('WsPingRequest', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['type']);
      final val = WsPingRequest(
        type: $checkedConvert('type', (v) => v as String),
      );
      return val;
    });

Map<String, dynamic> _$WsPingRequestToJson(WsPingRequest instance) =>
    <String, dynamic>{'type': instance.type};
