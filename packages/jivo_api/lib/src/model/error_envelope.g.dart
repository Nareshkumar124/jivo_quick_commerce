// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'error_envelope.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ErrorEnvelopeCWProxy {
  ErrorEnvelope error(ErrorBody error);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ErrorEnvelope(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ErrorEnvelope(...).copyWith(id: 12, name: "My name")
  /// ````
  ErrorEnvelope call({ErrorBody error});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfErrorEnvelope.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfErrorEnvelope.copyWith.fieldName(...)`
class _$ErrorEnvelopeCWProxyImpl implements _$ErrorEnvelopeCWProxy {
  const _$ErrorEnvelopeCWProxyImpl(this._value);

  final ErrorEnvelope _value;

  @override
  ErrorEnvelope error(ErrorBody error) => this(error: error);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ErrorEnvelope(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ErrorEnvelope(...).copyWith(id: 12, name: "My name")
  /// ````
  ErrorEnvelope call({Object? error = const $CopyWithPlaceholder()}) {
    return ErrorEnvelope(
      error: error == const $CopyWithPlaceholder()
          ? _value.error
          // ignore: cast_nullable_to_non_nullable
          : error as ErrorBody,
    );
  }
}

extension $ErrorEnvelopeCopyWith on ErrorEnvelope {
  /// Returns a callable class that can be used as follows: `instanceOfErrorEnvelope.copyWith(...)` or like so:`instanceOfErrorEnvelope.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ErrorEnvelopeCWProxy get copyWith => _$ErrorEnvelopeCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ErrorEnvelope _$ErrorEnvelopeFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ErrorEnvelope', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['error']);
      final val = ErrorEnvelope(
        error: $checkedConvert(
          'error',
          (v) => ErrorBody.fromJson(v as Map<String, dynamic>),
        ),
      );
      return val;
    });

Map<String, dynamic> _$ErrorEnvelopeToJson(ErrorEnvelope instance) =>
    <String, dynamic>{'error': instance.error.toJson()};
