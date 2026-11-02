// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'image_set.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ImageSetCWProxy {
  ImageSet thumbnail(String thumbnail);

  ImageSet medium(String medium);

  ImageSet large(String large);

  ImageSet altText(String altText);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ImageSet(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ImageSet(...).copyWith(id: 12, name: "My name")
  /// ````
  ImageSet call({
    String thumbnail,
    String medium,
    String large,
    String altText,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfImageSet.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfImageSet.copyWith.fieldName(...)`
class _$ImageSetCWProxyImpl implements _$ImageSetCWProxy {
  const _$ImageSetCWProxyImpl(this._value);

  final ImageSet _value;

  @override
  ImageSet thumbnail(String thumbnail) => this(thumbnail: thumbnail);

  @override
  ImageSet medium(String medium) => this(medium: medium);

  @override
  ImageSet large(String large) => this(large: large);

  @override
  ImageSet altText(String altText) => this(altText: altText);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ImageSet(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ImageSet(...).copyWith(id: 12, name: "My name")
  /// ````
  ImageSet call({
    Object? thumbnail = const $CopyWithPlaceholder(),
    Object? medium = const $CopyWithPlaceholder(),
    Object? large = const $CopyWithPlaceholder(),
    Object? altText = const $CopyWithPlaceholder(),
  }) {
    return ImageSet(
      thumbnail: thumbnail == const $CopyWithPlaceholder()
          ? _value.thumbnail
          // ignore: cast_nullable_to_non_nullable
          : thumbnail as String,
      medium: medium == const $CopyWithPlaceholder()
          ? _value.medium
          // ignore: cast_nullable_to_non_nullable
          : medium as String,
      large: large == const $CopyWithPlaceholder()
          ? _value.large
          // ignore: cast_nullable_to_non_nullable
          : large as String,
      altText: altText == const $CopyWithPlaceholder()
          ? _value.altText
          // ignore: cast_nullable_to_non_nullable
          : altText as String,
    );
  }
}

extension $ImageSetCopyWith on ImageSet {
  /// Returns a callable class that can be used as follows: `instanceOfImageSet.copyWith(...)` or like so:`instanceOfImageSet.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ImageSetCWProxy get copyWith => _$ImageSetCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ImageSet _$ImageSetFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ImageSet', json, ($checkedConvert) {
      $checkKeys(
        json,
        requiredKeys: const ['thumbnail', 'medium', 'large', 'alt_text'],
      );
      final val = ImageSet(
        thumbnail: $checkedConvert('thumbnail', (v) => v as String),
        medium: $checkedConvert('medium', (v) => v as String),
        large: $checkedConvert('large', (v) => v as String),
        altText: $checkedConvert('alt_text', (v) => v as String),
      );
      return val;
    }, fieldKeyMap: const {'altText': 'alt_text'});

Map<String, dynamic> _$ImageSetToJson(ImageSet instance) => <String, dynamic>{
  'thumbnail': instance.thumbnail,
  'medium': instance.medium,
  'large': instance.large,
  'alt_text': instance.altText,
};
