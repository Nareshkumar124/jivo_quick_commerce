// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'policy_urls.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$PolicyUrlsCWProxy {
  PolicyUrls terms(String terms);

  PolicyUrls privacy(String privacy);

  PolicyUrls refund(String refund);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PolicyUrls(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PolicyUrls(...).copyWith(id: 12, name: "My name")
  /// ````
  PolicyUrls call({String terms, String privacy, String refund});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfPolicyUrls.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfPolicyUrls.copyWith.fieldName(...)`
class _$PolicyUrlsCWProxyImpl implements _$PolicyUrlsCWProxy {
  const _$PolicyUrlsCWProxyImpl(this._value);

  final PolicyUrls _value;

  @override
  PolicyUrls terms(String terms) => this(terms: terms);

  @override
  PolicyUrls privacy(String privacy) => this(privacy: privacy);

  @override
  PolicyUrls refund(String refund) => this(refund: refund);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PolicyUrls(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PolicyUrls(...).copyWith(id: 12, name: "My name")
  /// ````
  PolicyUrls call({
    Object? terms = const $CopyWithPlaceholder(),
    Object? privacy = const $CopyWithPlaceholder(),
    Object? refund = const $CopyWithPlaceholder(),
  }) {
    return PolicyUrls(
      terms: terms == const $CopyWithPlaceholder()
          ? _value.terms
          // ignore: cast_nullable_to_non_nullable
          : terms as String,
      privacy: privacy == const $CopyWithPlaceholder()
          ? _value.privacy
          // ignore: cast_nullable_to_non_nullable
          : privacy as String,
      refund: refund == const $CopyWithPlaceholder()
          ? _value.refund
          // ignore: cast_nullable_to_non_nullable
          : refund as String,
    );
  }
}

extension $PolicyUrlsCopyWith on PolicyUrls {
  /// Returns a callable class that can be used as follows: `instanceOfPolicyUrls.copyWith(...)` or like so:`instanceOfPolicyUrls.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$PolicyUrlsCWProxy get copyWith => _$PolicyUrlsCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PolicyUrls _$PolicyUrlsFromJson(Map<String, dynamic> json) =>
    $checkedCreate('PolicyUrls', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['terms', 'privacy', 'refund']);
      final val = PolicyUrls(
        terms: $checkedConvert('terms', (v) => v as String),
        privacy: $checkedConvert('privacy', (v) => v as String),
        refund: $checkedConvert('refund', (v) => v as String),
      );
      return val;
    });

Map<String, dynamic> _$PolicyUrlsToJson(PolicyUrls instance) =>
    <String, dynamic>{
      'terms': instance.terms,
      'privacy': instance.privacy,
      'refund': instance.refund,
    };
