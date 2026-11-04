// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cart_line_issue.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CartLineIssueCWProxy {
  CartLineIssue code(CartLineIssueCodeEnum code);

  CartLineIssue message(String message);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CartLineIssue(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CartLineIssue(...).copyWith(id: 12, name: "My name")
  /// ````
  CartLineIssue call({CartLineIssueCodeEnum code, String message});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCartLineIssue.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCartLineIssue.copyWith.fieldName(...)`
class _$CartLineIssueCWProxyImpl implements _$CartLineIssueCWProxy {
  const _$CartLineIssueCWProxyImpl(this._value);

  final CartLineIssue _value;

  @override
  CartLineIssue code(CartLineIssueCodeEnum code) => this(code: code);

  @override
  CartLineIssue message(String message) => this(message: message);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CartLineIssue(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CartLineIssue(...).copyWith(id: 12, name: "My name")
  /// ````
  CartLineIssue call({
    Object? code = const $CopyWithPlaceholder(),
    Object? message = const $CopyWithPlaceholder(),
  }) {
    return CartLineIssue(
      code: code == const $CopyWithPlaceholder()
          ? _value.code
          // ignore: cast_nullable_to_non_nullable
          : code as CartLineIssueCodeEnum,
      message: message == const $CopyWithPlaceholder()
          ? _value.message
          // ignore: cast_nullable_to_non_nullable
          : message as String,
    );
  }
}

extension $CartLineIssueCopyWith on CartLineIssue {
  /// Returns a callable class that can be used as follows: `instanceOfCartLineIssue.copyWith(...)` or like so:`instanceOfCartLineIssue.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CartLineIssueCWProxy get copyWith => _$CartLineIssueCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CartLineIssue _$CartLineIssueFromJson(Map<String, dynamic> json) =>
    $checkedCreate('CartLineIssue', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['code', 'message']);
      final val = CartLineIssue(
        code: $checkedConvert(
          'code',
          (v) => $enumDecode(
            _$CartLineIssueCodeEnumEnumMap,
            v,
            unknownValue: CartLineIssueCodeEnum.unknownDefaultOpenApi,
          ),
        ),
        message: $checkedConvert('message', (v) => v as String),
      );
      return val;
    });

Map<String, dynamic> _$CartLineIssueToJson(CartLineIssue instance) =>
    <String, dynamic>{
      'code': _$CartLineIssueCodeEnumEnumMap[instance.code]!,
      'message': instance.message,
    };

const _$CartLineIssueCodeEnumEnumMap = {
  CartLineIssueCodeEnum.OUT_OF_STOCK: 'OUT_OF_STOCK',
  CartLineIssueCodeEnum.QUANTITY_UNAVAILABLE: 'QUANTITY_UNAVAILABLE',
  CartLineIssueCodeEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
