// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'token_pair.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$TokenPairCWProxy {
  TokenPair access(String access);

  TokenPair refresh(String refresh);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `TokenPair(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// TokenPair(...).copyWith(id: 12, name: "My name")
  /// ````
  TokenPair call({String access, String refresh});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfTokenPair.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfTokenPair.copyWith.fieldName(...)`
class _$TokenPairCWProxyImpl implements _$TokenPairCWProxy {
  const _$TokenPairCWProxyImpl(this._value);

  final TokenPair _value;

  @override
  TokenPair access(String access) => this(access: access);

  @override
  TokenPair refresh(String refresh) => this(refresh: refresh);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `TokenPair(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// TokenPair(...).copyWith(id: 12, name: "My name")
  /// ````
  TokenPair call({
    Object? access = const $CopyWithPlaceholder(),
    Object? refresh = const $CopyWithPlaceholder(),
  }) {
    return TokenPair(
      access: access == const $CopyWithPlaceholder()
          ? _value.access
          // ignore: cast_nullable_to_non_nullable
          : access as String,
      refresh: refresh == const $CopyWithPlaceholder()
          ? _value.refresh
          // ignore: cast_nullable_to_non_nullable
          : refresh as String,
    );
  }
}

extension $TokenPairCopyWith on TokenPair {
  /// Returns a callable class that can be used as follows: `instanceOfTokenPair.copyWith(...)` or like so:`instanceOfTokenPair.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$TokenPairCWProxy get copyWith => _$TokenPairCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TokenPair _$TokenPairFromJson(Map<String, dynamic> json) =>
    $checkedCreate('TokenPair', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['access', 'refresh']);
      final val = TokenPair(
        access: $checkedConvert('access', (v) => v as String),
        refresh: $checkedConvert('refresh', (v) => v as String),
      );
      return val;
    });

Map<String, dynamic> _$TokenPairToJson(TokenPair instance) => <String, dynamic>{
  'access': instance.access,
  'refresh': instance.refresh,
};
