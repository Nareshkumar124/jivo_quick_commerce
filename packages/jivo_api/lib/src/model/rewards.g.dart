// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rewards.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$RewardsCWProxy {
  Rewards available(List<Reward> available);

  Rewards history(List<RewardHistoryEntry> history);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `Rewards(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// Rewards(...).copyWith(id: 12, name: "My name")
  /// ````
  Rewards call({List<Reward> available, List<RewardHistoryEntry> history});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfRewards.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfRewards.copyWith.fieldName(...)`
class _$RewardsCWProxyImpl implements _$RewardsCWProxy {
  const _$RewardsCWProxyImpl(this._value);

  final Rewards _value;

  @override
  Rewards available(List<Reward> available) => this(available: available);

  @override
  Rewards history(List<RewardHistoryEntry> history) => this(history: history);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `Rewards(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// Rewards(...).copyWith(id: 12, name: "My name")
  /// ````
  Rewards call({
    Object? available = const $CopyWithPlaceholder(),
    Object? history = const $CopyWithPlaceholder(),
  }) {
    return Rewards(
      available: available == const $CopyWithPlaceholder()
          ? _value.available
          // ignore: cast_nullable_to_non_nullable
          : available as List<Reward>,
      history: history == const $CopyWithPlaceholder()
          ? _value.history
          // ignore: cast_nullable_to_non_nullable
          : history as List<RewardHistoryEntry>,
    );
  }
}

extension $RewardsCopyWith on Rewards {
  /// Returns a callable class that can be used as follows: `instanceOfRewards.copyWith(...)` or like so:`instanceOfRewards.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$RewardsCWProxy get copyWith => _$RewardsCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Rewards _$RewardsFromJson(Map<String, dynamic> json) => $checkedCreate(
  'Rewards',
  json,
  ($checkedConvert) {
    $checkKeys(json, requiredKeys: const ['available', 'history']);
    final val = Rewards(
      available: $checkedConvert(
        'available',
        (v) => (v as List<dynamic>)
            .map((e) => Reward.fromJson(e as Map<String, dynamic>))
            .toList(),
      ),
      history: $checkedConvert(
        'history',
        (v) => (v as List<dynamic>)
            .map((e) => RewardHistoryEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
      ),
    );
    return val;
  },
);

Map<String, dynamic> _$RewardsToJson(Rewards instance) => <String, dynamic>{
  'available': instance.available.map((e) => e.toJson()).toList(),
  'history': instance.history.map((e) => e.toJson()).toList(),
};
