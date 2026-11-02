// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'patched_address_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$PatchedAddressRequestCWProxy {
  PatchedAddressRequest label(AddressLabelEnum? label);

  PatchedAddressRequest customLabel(String? customLabel);

  PatchedAddressRequest receiverName(String? receiverName);

  PatchedAddressRequest receiverPhone(String? receiverPhone);

  PatchedAddressRequest house(String? house);

  PatchedAddressRequest buildingStreet(String? buildingStreet);

  PatchedAddressRequest landmark(String? landmark);

  PatchedAddressRequest area(String? area);

  PatchedAddressRequest city(String? city);

  PatchedAddressRequest state(String? state);

  PatchedAddressRequest pincode(String? pincode);

  PatchedAddressRequest lat(double? lat);

  PatchedAddressRequest lng(double? lng);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PatchedAddressRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PatchedAddressRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  PatchedAddressRequest call({
    AddressLabelEnum? label,
    String? customLabel,
    String? receiverName,
    String? receiverPhone,
    String? house,
    String? buildingStreet,
    String? landmark,
    String? area,
    String? city,
    String? state,
    String? pincode,
    double? lat,
    double? lng,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfPatchedAddressRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfPatchedAddressRequest.copyWith.fieldName(...)`
class _$PatchedAddressRequestCWProxyImpl
    implements _$PatchedAddressRequestCWProxy {
  const _$PatchedAddressRequestCWProxyImpl(this._value);

  final PatchedAddressRequest _value;

  @override
  PatchedAddressRequest label(AddressLabelEnum? label) => this(label: label);

  @override
  PatchedAddressRequest customLabel(String? customLabel) =>
      this(customLabel: customLabel);

  @override
  PatchedAddressRequest receiverName(String? receiverName) =>
      this(receiverName: receiverName);

  @override
  PatchedAddressRequest receiverPhone(String? receiverPhone) =>
      this(receiverPhone: receiverPhone);

  @override
  PatchedAddressRequest house(String? house) => this(house: house);

  @override
  PatchedAddressRequest buildingStreet(String? buildingStreet) =>
      this(buildingStreet: buildingStreet);

  @override
  PatchedAddressRequest landmark(String? landmark) => this(landmark: landmark);

  @override
  PatchedAddressRequest area(String? area) => this(area: area);

  @override
  PatchedAddressRequest city(String? city) => this(city: city);

  @override
  PatchedAddressRequest state(String? state) => this(state: state);

  @override
  PatchedAddressRequest pincode(String? pincode) => this(pincode: pincode);

  @override
  PatchedAddressRequest lat(double? lat) => this(lat: lat);

  @override
  PatchedAddressRequest lng(double? lng) => this(lng: lng);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PatchedAddressRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PatchedAddressRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  PatchedAddressRequest call({
    Object? label = const $CopyWithPlaceholder(),
    Object? customLabel = const $CopyWithPlaceholder(),
    Object? receiverName = const $CopyWithPlaceholder(),
    Object? receiverPhone = const $CopyWithPlaceholder(),
    Object? house = const $CopyWithPlaceholder(),
    Object? buildingStreet = const $CopyWithPlaceholder(),
    Object? landmark = const $CopyWithPlaceholder(),
    Object? area = const $CopyWithPlaceholder(),
    Object? city = const $CopyWithPlaceholder(),
    Object? state = const $CopyWithPlaceholder(),
    Object? pincode = const $CopyWithPlaceholder(),
    Object? lat = const $CopyWithPlaceholder(),
    Object? lng = const $CopyWithPlaceholder(),
  }) {
    return PatchedAddressRequest(
      label: label == const $CopyWithPlaceholder()
          ? _value.label
          // ignore: cast_nullable_to_non_nullable
          : label as AddressLabelEnum?,
      customLabel: customLabel == const $CopyWithPlaceholder()
          ? _value.customLabel
          // ignore: cast_nullable_to_non_nullable
          : customLabel as String?,
      receiverName: receiverName == const $CopyWithPlaceholder()
          ? _value.receiverName
          // ignore: cast_nullable_to_non_nullable
          : receiverName as String?,
      receiverPhone: receiverPhone == const $CopyWithPlaceholder()
          ? _value.receiverPhone
          // ignore: cast_nullable_to_non_nullable
          : receiverPhone as String?,
      house: house == const $CopyWithPlaceholder()
          ? _value.house
          // ignore: cast_nullable_to_non_nullable
          : house as String?,
      buildingStreet: buildingStreet == const $CopyWithPlaceholder()
          ? _value.buildingStreet
          // ignore: cast_nullable_to_non_nullable
          : buildingStreet as String?,
      landmark: landmark == const $CopyWithPlaceholder()
          ? _value.landmark
          // ignore: cast_nullable_to_non_nullable
          : landmark as String?,
      area: area == const $CopyWithPlaceholder()
          ? _value.area
          // ignore: cast_nullable_to_non_nullable
          : area as String?,
      city: city == const $CopyWithPlaceholder()
          ? _value.city
          // ignore: cast_nullable_to_non_nullable
          : city as String?,
      state: state == const $CopyWithPlaceholder()
          ? _value.state
          // ignore: cast_nullable_to_non_nullable
          : state as String?,
      pincode: pincode == const $CopyWithPlaceholder()
          ? _value.pincode
          // ignore: cast_nullable_to_non_nullable
          : pincode as String?,
      lat: lat == const $CopyWithPlaceholder()
          ? _value.lat
          // ignore: cast_nullable_to_non_nullable
          : lat as double?,
      lng: lng == const $CopyWithPlaceholder()
          ? _value.lng
          // ignore: cast_nullable_to_non_nullable
          : lng as double?,
    );
  }
}

extension $PatchedAddressRequestCopyWith on PatchedAddressRequest {
  /// Returns a callable class that can be used as follows: `instanceOfPatchedAddressRequest.copyWith(...)` or like so:`instanceOfPatchedAddressRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$PatchedAddressRequestCWProxy get copyWith =>
      _$PatchedAddressRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PatchedAddressRequest _$PatchedAddressRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'PatchedAddressRequest',
  json,
  ($checkedConvert) {
    final val = PatchedAddressRequest(
      label: $checkedConvert(
        'label',
        (v) => $enumDecodeNullable(
          _$AddressLabelEnumEnumMap,
          v,
          unknownValue: AddressLabelEnum.unknownDefaultOpenApi,
        ),
      ),
      customLabel: $checkedConvert('custom_label', (v) => v as String?),
      receiverName: $checkedConvert('receiver_name', (v) => v as String?),
      receiverPhone: $checkedConvert('receiver_phone', (v) => v as String?),
      house: $checkedConvert('house', (v) => v as String?),
      buildingStreet: $checkedConvert('building_street', (v) => v as String?),
      landmark: $checkedConvert('landmark', (v) => v as String?),
      area: $checkedConvert('area', (v) => v as String?),
      city: $checkedConvert('city', (v) => v as String?),
      state: $checkedConvert('state', (v) => v as String?),
      pincode: $checkedConvert('pincode', (v) => v as String?),
      lat: $checkedConvert('lat', (v) => (v as num?)?.toDouble()),
      lng: $checkedConvert('lng', (v) => (v as num?)?.toDouble()),
    );
    return val;
  },
  fieldKeyMap: const {
    'customLabel': 'custom_label',
    'receiverName': 'receiver_name',
    'receiverPhone': 'receiver_phone',
    'buildingStreet': 'building_street',
  },
);

Map<String, dynamic> _$PatchedAddressRequestToJson(
  PatchedAddressRequest instance,
) => <String, dynamic>{
  'label': ?_$AddressLabelEnumEnumMap[instance.label],
  'custom_label': ?instance.customLabel,
  'receiver_name': ?instance.receiverName,
  'receiver_phone': ?instance.receiverPhone,
  'house': ?instance.house,
  'building_street': ?instance.buildingStreet,
  'landmark': ?instance.landmark,
  'area': ?instance.area,
  'city': ?instance.city,
  'state': ?instance.state,
  'pincode': ?instance.pincode,
  'lat': ?instance.lat,
  'lng': ?instance.lng,
};

const _$AddressLabelEnumEnumMap = {
  AddressLabelEnum.home: 'home',
  AddressLabelEnum.work: 'work',
  AddressLabelEnum.other: 'other',
  AddressLabelEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
