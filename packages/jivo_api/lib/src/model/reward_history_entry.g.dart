// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reward_history_entry.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$RewardHistoryEntryCWProxy {
  RewardHistoryEntry at(DateTime at);

  RewardHistoryEntry kind(RewardHistoryKindEnum kind);

  RewardHistoryEntry title(String title);

  RewardHistoryEntry quantity(int quantity);

  RewardHistoryEntry orderNumber(String? orderNumber);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RewardHistoryEntry(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RewardHistoryEntry(...).copyWith(id: 12, name: "My name")
  /// ````
  RewardHistoryEntry call({
    DateTime at,
    RewardHistoryKindEnum kind,
    String title,
    int quantity,
    String? orderNumber,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfRewardHistoryEntry.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfRewardHistoryEntry.copyWith.fieldName(...)`
class _$RewardHistoryEntryCWProxyImpl implements _$RewardHistoryEntryCWProxy {
  const _$RewardHistoryEntryCWProxyImpl(this._value);

  final RewardHistoryEntry _value;

  @override
  RewardHistoryEntry at(DateTime at) => this(at: at);

  @override
  RewardHistoryEntry kind(RewardHistoryKindEnum kind) => this(kind: kind);

  @override
  RewardHistoryEntry title(String title) => this(title: title);

  @override
  RewardHistoryEntry quantity(int quantity) => this(quantity: quantity);

  @override
  RewardHistoryEntry orderNumber(String? orderNumber) =>
      this(orderNumber: orderNumber);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RewardHistoryEntry(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RewardHistoryEntry(...).copyWith(id: 12, name: "My name")
  /// ````
  RewardHistoryEntry call({
    Object? at = const $CopyWithPlaceholder(),
    Object? kind = const $CopyWithPlaceholder(),
    Object? title = const $CopyWithPlaceholder(),
    Object? quantity = const $CopyWithPlaceholder(),
    Object? orderNumber = const $CopyWithPlaceholder(),
  }) {
    return RewardHistoryEntry(
      at: at == const $CopyWithPlaceholder()
          ? _value.at
          // ignore: cast_nullable_to_non_nullable
          : at as DateTime,
      kind: kind == const $CopyWithPlaceholder()
          ? _value.kind
          // ignore: cast_nullable_to_non_nullable
          : kind as RewardHistoryKindEnum,
      title: title == const $CopyWithPlaceholder()
          ? _value.title
          // ignore: cast_nullable_to_non_nullable
          : title as String,
      quantity: quantity == const $CopyWithPlaceholder()
          ? _value.quantity
          // ignore: cast_nullable_to_non_nullable
          : quantity as int,
      orderNumber: orderNumber == const $CopyWithPlaceholder()
          ? _value.orderNumber
          // ignore: cast_nullable_to_non_nullable
          : orderNumber as String?,
    );
  }
}

extension $RewardHistoryEntryCopyWith on RewardHistoryEntry {
  /// Returns a callable class that can be used as follows: `instanceOfRewardHistoryEntry.copyWith(...)` or like so:`instanceOfRewardHistoryEntry.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$RewardHistoryEntryCWProxy get copyWith =>
      _$RewardHistoryEntryCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RewardHistoryEntry _$RewardHistoryEntryFromJson(Map<String, dynamic> json) =>
    $checkedCreate('RewardHistoryEntry', json, ($checkedConvert) {
      $checkKeys(
        json,
        requiredKeys: const ['at', 'kind', 'title', 'quantity', 'order_number'],
      );
      final val = RewardHistoryEntry(
        at: $checkedConvert('at', (v) => DateTime.parse(v as String)),
        kind: $checkedConvert(
          'kind',
          (v) => $enumDecode(
            _$RewardHistoryKindEnumEnumMap,
            v,
            unknownValue: RewardHistoryKindEnum.unknownDefaultOpenApi,
          ),
        ),
        title: $checkedConvert('title', (v) => v as String),
        quantity: $checkedConvert('quantity', (v) => (v as num).toInt()),
        orderNumber: $checkedConvert('order_number', (v) => v as String?),
      );
      return val;
    }, fieldKeyMap: const {'orderNumber': 'order_number'});

Map<String, dynamic> _$RewardHistoryEntryToJson(RewardHistoryEntry instance) =>
    <String, dynamic>{
      'at': instance.at.toIso8601String(),
      'kind': _$RewardHistoryKindEnumEnumMap[instance.kind]!,
      'title': instance.title,
      'quantity': instance.quantity,
      'order_number': instance.orderNumber,
    };

const _$RewardHistoryKindEnumEnumMap = {
  RewardHistoryKindEnum.EARNED: 'EARNED',
  RewardHistoryKindEnum.CLAIMED: 'CLAIMED',
  RewardHistoryKindEnum.USED: 'USED',
  RewardHistoryKindEnum.EXPIRED: 'EXPIRED',
  RewardHistoryKindEnum.VOLUME_FREE: 'VOLUME_FREE',
  RewardHistoryKindEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
