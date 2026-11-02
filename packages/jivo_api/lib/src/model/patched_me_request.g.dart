// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'patched_me_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$PatchedMeRequestCWProxy {
  PatchedMeRequest name(String? name);

  PatchedMeRequest email(String? email);

  PatchedMeRequest marketingOptIn(bool? marketingOptIn);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PatchedMeRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PatchedMeRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  PatchedMeRequest call({String? name, String? email, bool? marketingOptIn});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfPatchedMeRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfPatchedMeRequest.copyWith.fieldName(...)`
class _$PatchedMeRequestCWProxyImpl implements _$PatchedMeRequestCWProxy {
  const _$PatchedMeRequestCWProxyImpl(this._value);

  final PatchedMeRequest _value;

  @override
  PatchedMeRequest name(String? name) => this(name: name);

  @override
  PatchedMeRequest email(String? email) => this(email: email);

  @override
  PatchedMeRequest marketingOptIn(bool? marketingOptIn) =>
      this(marketingOptIn: marketingOptIn);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PatchedMeRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PatchedMeRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  PatchedMeRequest call({
    Object? name = const $CopyWithPlaceholder(),
    Object? email = const $CopyWithPlaceholder(),
    Object? marketingOptIn = const $CopyWithPlaceholder(),
  }) {
    return PatchedMeRequest(
      name: name == const $CopyWithPlaceholder()
          ? _value.name
          // ignore: cast_nullable_to_non_nullable
          : name as String?,
      email: email == const $CopyWithPlaceholder()
          ? _value.email
          // ignore: cast_nullable_to_non_nullable
          : email as String?,
      marketingOptIn: marketingOptIn == const $CopyWithPlaceholder()
          ? _value.marketingOptIn
          // ignore: cast_nullable_to_non_nullable
          : marketingOptIn as bool?,
    );
  }
}

extension $PatchedMeRequestCopyWith on PatchedMeRequest {
  /// Returns a callable class that can be used as follows: `instanceOfPatchedMeRequest.copyWith(...)` or like so:`instanceOfPatchedMeRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$PatchedMeRequestCWProxy get copyWith => _$PatchedMeRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PatchedMeRequest _$PatchedMeRequestFromJson(Map<String, dynamic> json) =>
    $checkedCreate('PatchedMeRequest', json, ($checkedConvert) {
      final val = PatchedMeRequest(
        name: $checkedConvert('name', (v) => v as String?),
        email: $checkedConvert('email', (v) => v as String?),
        marketingOptIn: $checkedConvert('marketing_opt_in', (v) => v as bool?),
      );
      return val;
    }, fieldKeyMap: const {'marketingOptIn': 'marketing_opt_in'});

Map<String, dynamic> _$PatchedMeRequestToJson(PatchedMeRequest instance) =>
    <String, dynamic>{
      'name': ?instance.name,
      'email': ?instance.email,
      'marketing_opt_in': ?instance.marketingOptIn,
    };
