// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'home_banner.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$HomeBannerCWProxy {
  HomeBanner id(int id);

  HomeBanner title(String title);

  HomeBanner image(ImageSet image);

  HomeBanner linkType(BannerLinkTypeEnum linkType);

  HomeBanner linkValue(String linkValue);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `HomeBanner(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// HomeBanner(...).copyWith(id: 12, name: "My name")
  /// ````
  HomeBanner call({
    int id,
    String title,
    ImageSet image,
    BannerLinkTypeEnum linkType,
    String linkValue,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfHomeBanner.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfHomeBanner.copyWith.fieldName(...)`
class _$HomeBannerCWProxyImpl implements _$HomeBannerCWProxy {
  const _$HomeBannerCWProxyImpl(this._value);

  final HomeBanner _value;

  @override
  HomeBanner id(int id) => this(id: id);

  @override
  HomeBanner title(String title) => this(title: title);

  @override
  HomeBanner image(ImageSet image) => this(image: image);

  @override
  HomeBanner linkType(BannerLinkTypeEnum linkType) => this(linkType: linkType);

  @override
  HomeBanner linkValue(String linkValue) => this(linkValue: linkValue);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `HomeBanner(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// HomeBanner(...).copyWith(id: 12, name: "My name")
  /// ````
  HomeBanner call({
    Object? id = const $CopyWithPlaceholder(),
    Object? title = const $CopyWithPlaceholder(),
    Object? image = const $CopyWithPlaceholder(),
    Object? linkType = const $CopyWithPlaceholder(),
    Object? linkValue = const $CopyWithPlaceholder(),
  }) {
    return HomeBanner(
      id: id == const $CopyWithPlaceholder()
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as int,
      title: title == const $CopyWithPlaceholder()
          ? _value.title
          // ignore: cast_nullable_to_non_nullable
          : title as String,
      image: image == const $CopyWithPlaceholder()
          ? _value.image
          // ignore: cast_nullable_to_non_nullable
          : image as ImageSet,
      linkType: linkType == const $CopyWithPlaceholder()
          ? _value.linkType
          // ignore: cast_nullable_to_non_nullable
          : linkType as BannerLinkTypeEnum,
      linkValue: linkValue == const $CopyWithPlaceholder()
          ? _value.linkValue
          // ignore: cast_nullable_to_non_nullable
          : linkValue as String,
    );
  }
}

extension $HomeBannerCopyWith on HomeBanner {
  /// Returns a callable class that can be used as follows: `instanceOfHomeBanner.copyWith(...)` or like so:`instanceOfHomeBanner.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$HomeBannerCWProxy get copyWith => _$HomeBannerCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

HomeBanner _$HomeBannerFromJson(Map<String, dynamic> json) =>
    $checkedCreate('HomeBanner', json, ($checkedConvert) {
      $checkKeys(
        json,
        requiredKeys: const ['id', 'title', 'image', 'link_type', 'link_value'],
      );
      final val = HomeBanner(
        id: $checkedConvert('id', (v) => (v as num).toInt()),
        title: $checkedConvert('title', (v) => v as String),
        image: $checkedConvert(
          'image',
          (v) => ImageSet.fromJson(v as Map<String, dynamic>),
        ),
        linkType: $checkedConvert(
          'link_type',
          (v) => $enumDecode(
            _$BannerLinkTypeEnumEnumMap,
            v,
            unknownValue: BannerLinkTypeEnum.unknownDefaultOpenApi,
          ),
        ),
        linkValue: $checkedConvert('link_value', (v) => v as String),
      );
      return val;
    }, fieldKeyMap: const {'linkType': 'link_type', 'linkValue': 'link_value'});

Map<String, dynamic> _$HomeBannerToJson(HomeBanner instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'image': instance.image.toJson(),
      'link_type': _$BannerLinkTypeEnumEnumMap[instance.linkType]!,
      'link_value': instance.linkValue,
    };

const _$BannerLinkTypeEnumEnumMap = {
  BannerLinkTypeEnum.category: 'category',
  BannerLinkTypeEnum.collection: 'collection',
  BannerLinkTypeEnum.product: 'product',
  BannerLinkTypeEnum.url: 'url',
  BannerLinkTypeEnum.none: 'none',
  BannerLinkTypeEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
