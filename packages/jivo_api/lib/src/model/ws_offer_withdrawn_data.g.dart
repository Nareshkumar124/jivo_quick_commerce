// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ws_offer_withdrawn_data.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$WsOfferWithdrawnDataCWProxy {
  WsOfferWithdrawnData offerId(int offerId);

  WsOfferWithdrawnData taskId(int taskId);

  WsOfferWithdrawnData reason(WsOfferWithdrawnDataReasonEnum reason);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WsOfferWithdrawnData(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WsOfferWithdrawnData(...).copyWith(id: 12, name: "My name")
  /// ````
  WsOfferWithdrawnData call({
    int offerId,
    int taskId,
    WsOfferWithdrawnDataReasonEnum reason,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfWsOfferWithdrawnData.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfWsOfferWithdrawnData.copyWith.fieldName(...)`
class _$WsOfferWithdrawnDataCWProxyImpl
    implements _$WsOfferWithdrawnDataCWProxy {
  const _$WsOfferWithdrawnDataCWProxyImpl(this._value);

  final WsOfferWithdrawnData _value;

  @override
  WsOfferWithdrawnData offerId(int offerId) => this(offerId: offerId);

  @override
  WsOfferWithdrawnData taskId(int taskId) => this(taskId: taskId);

  @override
  WsOfferWithdrawnData reason(WsOfferWithdrawnDataReasonEnum reason) =>
      this(reason: reason);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WsOfferWithdrawnData(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WsOfferWithdrawnData(...).copyWith(id: 12, name: "My name")
  /// ````
  WsOfferWithdrawnData call({
    Object? offerId = const $CopyWithPlaceholder(),
    Object? taskId = const $CopyWithPlaceholder(),
    Object? reason = const $CopyWithPlaceholder(),
  }) {
    return WsOfferWithdrawnData(
      offerId: offerId == const $CopyWithPlaceholder()
          ? _value.offerId
          // ignore: cast_nullable_to_non_nullable
          : offerId as int,
      taskId: taskId == const $CopyWithPlaceholder()
          ? _value.taskId
          // ignore: cast_nullable_to_non_nullable
          : taskId as int,
      reason: reason == const $CopyWithPlaceholder()
          ? _value.reason
          // ignore: cast_nullable_to_non_nullable
          : reason as WsOfferWithdrawnDataReasonEnum,
    );
  }
}

extension $WsOfferWithdrawnDataCopyWith on WsOfferWithdrawnData {
  /// Returns a callable class that can be used as follows: `instanceOfWsOfferWithdrawnData.copyWith(...)` or like so:`instanceOfWsOfferWithdrawnData.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$WsOfferWithdrawnDataCWProxy get copyWith =>
      _$WsOfferWithdrawnDataCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WsOfferWithdrawnData _$WsOfferWithdrawnDataFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('WsOfferWithdrawnData', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['offer_id', 'task_id', 'reason']);
  final val = WsOfferWithdrawnData(
    offerId: $checkedConvert('offer_id', (v) => (v as num).toInt()),
    taskId: $checkedConvert('task_id', (v) => (v as num).toInt()),
    reason: $checkedConvert(
      'reason',
      (v) => $enumDecode(
        _$WsOfferWithdrawnDataReasonEnumEnumMap,
        v,
        unknownValue: WsOfferWithdrawnDataReasonEnum.unknownDefaultOpenApi,
      ),
    ),
  );
  return val;
}, fieldKeyMap: const {'offerId': 'offer_id', 'taskId': 'task_id'});

Map<String, dynamic> _$WsOfferWithdrawnDataToJson(
  WsOfferWithdrawnData instance,
) => <String, dynamic>{
  'offer_id': instance.offerId,
  'task_id': instance.taskId,
  'reason': _$WsOfferWithdrawnDataReasonEnumEnumMap[instance.reason]!,
};

const _$WsOfferWithdrawnDataReasonEnumEnumMap = {
  WsOfferWithdrawnDataReasonEnum.EXPIRED: 'EXPIRED',
  WsOfferWithdrawnDataReasonEnum.TAKEN: 'TAKEN',
  WsOfferWithdrawnDataReasonEnum.ORDER_CANCELLED: 'ORDER_CANCELLED',
  WsOfferWithdrawnDataReasonEnum.REASSIGNED: 'REASSIGNED',
  WsOfferWithdrawnDataReasonEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
