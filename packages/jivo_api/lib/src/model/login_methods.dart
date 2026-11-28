// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/app_enum.dart';
import 'package:jivo_api/src/model/login_method_enum.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'login_methods.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class LoginMethods {
  /// Returns a new [LoginMethods] instance.
  LoginMethods({required this.app, required this.methods});

  /// The app asked about.  * `customer` - Customer app * `rider` - Rider app
  @JsonKey(
    name: r'app',
    required: true,
    includeIfNull: false,
    unknownEnumValue: AppEnum.unknownDefaultOpenApi,
  )
  final AppEnum app;

  /// The sign-in methods to offer, in display order: `[\"phone\"]`, `[\"email\"]` or `[\"phone\", \"email\"]` (show a Phone / Email choice). Never empty.
  @JsonKey(
    name: r'methods',
    required: true,
    includeIfNull: false,
    unknownEnumValue: LoginMethodEnum.unknownDefaultOpenApi,
  )
  final List<LoginMethodEnum> methods;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoginMethods && other.app == app && other.methods == methods;

  @override
  int get hashCode => app.hashCode + methods.hashCode;

  factory LoginMethods.fromJson(Map<String, dynamic> json) =>
      _$LoginMethodsFromJson(json);

  Map<String, dynamic> toJson() => _$LoginMethodsToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
