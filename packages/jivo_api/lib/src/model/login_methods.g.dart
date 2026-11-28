// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'login_methods.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$LoginMethodsCWProxy {
  LoginMethods app(AppEnum app);

  LoginMethods methods(List<LoginMethodEnum> methods);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `LoginMethods(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// LoginMethods(...).copyWith(id: 12, name: "My name")
  /// ````
  LoginMethods call({AppEnum app, List<LoginMethodEnum> methods});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfLoginMethods.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfLoginMethods.copyWith.fieldName(...)`
class _$LoginMethodsCWProxyImpl implements _$LoginMethodsCWProxy {
  const _$LoginMethodsCWProxyImpl(this._value);

  final LoginMethods _value;

  @override
  LoginMethods app(AppEnum app) => this(app: app);

  @override
  LoginMethods methods(List<LoginMethodEnum> methods) => this(methods: methods);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `LoginMethods(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// LoginMethods(...).copyWith(id: 12, name: "My name")
  /// ````
  LoginMethods call({
    Object? app = const $CopyWithPlaceholder(),
    Object? methods = const $CopyWithPlaceholder(),
  }) {
    return LoginMethods(
      app: app == const $CopyWithPlaceholder()
          ? _value.app
          // ignore: cast_nullable_to_non_nullable
          : app as AppEnum,
      methods: methods == const $CopyWithPlaceholder()
          ? _value.methods
          // ignore: cast_nullable_to_non_nullable
          : methods as List<LoginMethodEnum>,
    );
  }
}

extension $LoginMethodsCopyWith on LoginMethods {
  /// Returns a callable class that can be used as follows: `instanceOfLoginMethods.copyWith(...)` or like so:`instanceOfLoginMethods.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$LoginMethodsCWProxy get copyWith => _$LoginMethodsCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LoginMethods _$LoginMethodsFromJson(Map<String, dynamic> json) =>
    $checkedCreate('LoginMethods', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['app', 'methods']);
      final val = LoginMethods(
        app: $checkedConvert(
          'app',
          (v) => $enumDecode(
            _$AppEnumEnumMap,
            v,
            unknownValue: AppEnum.unknownDefaultOpenApi,
          ),
        ),
        methods: $checkedConvert(
          'methods',
          (v) => (v as List<dynamic>)
              .map(
                (e) => $enumDecode(
                  _$LoginMethodEnumEnumMap,
                  e,
                  unknownValue: LoginMethodEnum.unknownDefaultOpenApi,
                ),
              )
              .toList(),
        ),
      );
      return val;
    });

Map<String, dynamic> _$LoginMethodsToJson(
  LoginMethods instance,
) => <String, dynamic>{
  'app': _$AppEnumEnumMap[instance.app]!,
  'methods': instance.methods.map((e) => _$LoginMethodEnumEnumMap[e]!).toList(),
};

const _$AppEnumEnumMap = {
  AppEnum.customer: 'customer',
  AppEnum.rider: 'rider',
  AppEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};

const _$LoginMethodEnumEnumMap = {
  LoginMethodEnum.phone: 'phone',
  LoginMethodEnum.email: 'email',
  LoginMethodEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
