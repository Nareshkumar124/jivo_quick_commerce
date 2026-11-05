// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rider_register_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$RiderRegisterRequestCWProxy {
  RiderRegisterRequest fullName(String fullName);

  RiderRegisterRequest dob(DateTime dob);

  RiderRegisterRequest emergencyContactName(String emergencyContactName);

  RiderRegisterRequest emergencyContactPhone(String emergencyContactPhone);

  RiderRegisterRequest preferredStoreId(int preferredStoreId);

  RiderRegisterRequest vehicleType(VehicleTypeEnum vehicleType);

  RiderRegisterRequest vehicleNumber(String? vehicleNumber);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RiderRegisterRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RiderRegisterRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  RiderRegisterRequest call({
    String fullName,
    DateTime dob,
    String emergencyContactName,
    String emergencyContactPhone,
    int preferredStoreId,
    VehicleTypeEnum vehicleType,
    String? vehicleNumber,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfRiderRegisterRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfRiderRegisterRequest.copyWith.fieldName(...)`
class _$RiderRegisterRequestCWProxyImpl
    implements _$RiderRegisterRequestCWProxy {
  const _$RiderRegisterRequestCWProxyImpl(this._value);

  final RiderRegisterRequest _value;

  @override
  RiderRegisterRequest fullName(String fullName) => this(fullName: fullName);

  @override
  RiderRegisterRequest dob(DateTime dob) => this(dob: dob);

  @override
  RiderRegisterRequest emergencyContactName(String emergencyContactName) =>
      this(emergencyContactName: emergencyContactName);

  @override
  RiderRegisterRequest emergencyContactPhone(String emergencyContactPhone) =>
      this(emergencyContactPhone: emergencyContactPhone);

  @override
  RiderRegisterRequest preferredStoreId(int preferredStoreId) =>
      this(preferredStoreId: preferredStoreId);

  @override
  RiderRegisterRequest vehicleType(VehicleTypeEnum vehicleType) =>
      this(vehicleType: vehicleType);

  @override
  RiderRegisterRequest vehicleNumber(String? vehicleNumber) =>
      this(vehicleNumber: vehicleNumber);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RiderRegisterRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RiderRegisterRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  RiderRegisterRequest call({
    Object? fullName = const $CopyWithPlaceholder(),
    Object? dob = const $CopyWithPlaceholder(),
    Object? emergencyContactName = const $CopyWithPlaceholder(),
    Object? emergencyContactPhone = const $CopyWithPlaceholder(),
    Object? preferredStoreId = const $CopyWithPlaceholder(),
    Object? vehicleType = const $CopyWithPlaceholder(),
    Object? vehicleNumber = const $CopyWithPlaceholder(),
  }) {
    return RiderRegisterRequest(
      fullName: fullName == const $CopyWithPlaceholder()
          ? _value.fullName
          // ignore: cast_nullable_to_non_nullable
          : fullName as String,
      dob: dob == const $CopyWithPlaceholder()
          ? _value.dob
          // ignore: cast_nullable_to_non_nullable
          : dob as DateTime,
      emergencyContactName: emergencyContactName == const $CopyWithPlaceholder()
          ? _value.emergencyContactName
          // ignore: cast_nullable_to_non_nullable
          : emergencyContactName as String,
      emergencyContactPhone:
          emergencyContactPhone == const $CopyWithPlaceholder()
          ? _value.emergencyContactPhone
          // ignore: cast_nullable_to_non_nullable
          : emergencyContactPhone as String,
      preferredStoreId: preferredStoreId == const $CopyWithPlaceholder()
          ? _value.preferredStoreId
          // ignore: cast_nullable_to_non_nullable
          : preferredStoreId as int,
      vehicleType: vehicleType == const $CopyWithPlaceholder()
          ? _value.vehicleType
          // ignore: cast_nullable_to_non_nullable
          : vehicleType as VehicleTypeEnum,
      vehicleNumber: vehicleNumber == const $CopyWithPlaceholder()
          ? _value.vehicleNumber
          // ignore: cast_nullable_to_non_nullable
          : vehicleNumber as String?,
    );
  }
}

extension $RiderRegisterRequestCopyWith on RiderRegisterRequest {
  /// Returns a callable class that can be used as follows: `instanceOfRiderRegisterRequest.copyWith(...)` or like so:`instanceOfRiderRegisterRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$RiderRegisterRequestCWProxy get copyWith =>
      _$RiderRegisterRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RiderRegisterRequest _$RiderRegisterRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'RiderRegisterRequest',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const [
        'full_name',
        'dob',
        'emergency_contact_name',
        'emergency_contact_phone',
        'preferred_store_id',
        'vehicle_type',
      ],
    );
    final val = RiderRegisterRequest(
      fullName: $checkedConvert('full_name', (v) => v as String),
      dob: $checkedConvert('dob', (v) => DateTime.parse(v as String)),
      emergencyContactName: $checkedConvert(
        'emergency_contact_name',
        (v) => v as String,
      ),
      emergencyContactPhone: $checkedConvert(
        'emergency_contact_phone',
        (v) => v as String,
      ),
      preferredStoreId: $checkedConvert(
        'preferred_store_id',
        (v) => (v as num).toInt(),
      ),
      vehicleType: $checkedConvert(
        'vehicle_type',
        (v) => $enumDecode(
          _$VehicleTypeEnumEnumMap,
          v,
          unknownValue: VehicleTypeEnum.unknownDefaultOpenApi,
        ),
      ),
      vehicleNumber: $checkedConvert('vehicle_number', (v) => v as String?),
    );
    return val;
  },
  fieldKeyMap: const {
    'fullName': 'full_name',
    'emergencyContactName': 'emergency_contact_name',
    'emergencyContactPhone': 'emergency_contact_phone',
    'preferredStoreId': 'preferred_store_id',
    'vehicleType': 'vehicle_type',
    'vehicleNumber': 'vehicle_number',
  },
);

Map<String, dynamic> _$RiderRegisterRequestToJson(
  RiderRegisterRequest instance,
) => <String, dynamic>{
  'full_name': instance.fullName,
  'dob': jivoDateToJson(instance.dob),
  'emergency_contact_name': instance.emergencyContactName,
  'emergency_contact_phone': instance.emergencyContactPhone,
  'preferred_store_id': instance.preferredStoreId,
  'vehicle_type': _$VehicleTypeEnumEnumMap[instance.vehicleType]!,
  'vehicle_number': ?instance.vehicleNumber,
};

const _$VehicleTypeEnumEnumMap = {
  VehicleTypeEnum.BICYCLE: 'BICYCLE',
  VehicleTypeEnum.E_BIKE: 'E_BIKE',
  VehicleTypeEnum.MOTORBIKE: 'MOTORBIKE',
  VehicleTypeEnum.SCOOTER: 'SCOOTER',
  VehicleTypeEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
