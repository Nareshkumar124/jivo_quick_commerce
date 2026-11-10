// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'store_list.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$StoreListCWProxy {
  StoreList results(List<RiderStore> results);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `StoreList(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// StoreList(...).copyWith(id: 12, name: "My name")
  /// ````
  StoreList call({List<RiderStore> results});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfStoreList.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfStoreList.copyWith.fieldName(...)`
class _$StoreListCWProxyImpl implements _$StoreListCWProxy {
  const _$StoreListCWProxyImpl(this._value);

  final StoreList _value;

  @override
  StoreList results(List<RiderStore> results) => this(results: results);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `StoreList(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// StoreList(...).copyWith(id: 12, name: "My name")
  /// ````
  StoreList call({Object? results = const $CopyWithPlaceholder()}) {
    return StoreList(
      results: results == const $CopyWithPlaceholder()
          ? _value.results
          // ignore: cast_nullable_to_non_nullable
          : results as List<RiderStore>,
    );
  }
}

extension $StoreListCopyWith on StoreList {
  /// Returns a callable class that can be used as follows: `instanceOfStoreList.copyWith(...)` or like so:`instanceOfStoreList.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$StoreListCWProxy get copyWith => _$StoreListCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

StoreList _$StoreListFromJson(Map<String, dynamic> json) =>
    $checkedCreate('StoreList', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['results']);
      final val = StoreList(
        results: $checkedConvert(
          'results',
          (v) => (v as List<dynamic>)
              .map((e) => RiderStore.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
      );
      return val;
    });

Map<String, dynamic> _$StoreListToJson(StoreList instance) => <String, dynamic>{
  'results': instance.results.map((e) => e.toJson()).toList(),
};
