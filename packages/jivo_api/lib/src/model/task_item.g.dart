// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_item.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$TaskItemCWProxy {
  TaskItem name(String name);

  TaskItem variant(String variant);

  TaskItem quantity(int quantity);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `TaskItem(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// TaskItem(...).copyWith(id: 12, name: "My name")
  /// ````
  TaskItem call({String name, String variant, int quantity});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfTaskItem.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfTaskItem.copyWith.fieldName(...)`
class _$TaskItemCWProxyImpl implements _$TaskItemCWProxy {
  const _$TaskItemCWProxyImpl(this._value);

  final TaskItem _value;

  @override
  TaskItem name(String name) => this(name: name);

  @override
  TaskItem variant(String variant) => this(variant: variant);

  @override
  TaskItem quantity(int quantity) => this(quantity: quantity);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `TaskItem(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// TaskItem(...).copyWith(id: 12, name: "My name")
  /// ````
  TaskItem call({
    Object? name = const $CopyWithPlaceholder(),
    Object? variant = const $CopyWithPlaceholder(),
    Object? quantity = const $CopyWithPlaceholder(),
  }) {
    return TaskItem(
      name: name == const $CopyWithPlaceholder()
          ? _value.name
          // ignore: cast_nullable_to_non_nullable
          : name as String,
      variant: variant == const $CopyWithPlaceholder()
          ? _value.variant
          // ignore: cast_nullable_to_non_nullable
          : variant as String,
      quantity: quantity == const $CopyWithPlaceholder()
          ? _value.quantity
          // ignore: cast_nullable_to_non_nullable
          : quantity as int,
    );
  }
}

extension $TaskItemCopyWith on TaskItem {
  /// Returns a callable class that can be used as follows: `instanceOfTaskItem.copyWith(...)` or like so:`instanceOfTaskItem.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$TaskItemCWProxy get copyWith => _$TaskItemCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TaskItem _$TaskItemFromJson(Map<String, dynamic> json) =>
    $checkedCreate('TaskItem', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['name', 'variant', 'quantity']);
      final val = TaskItem(
        name: $checkedConvert('name', (v) => v as String),
        variant: $checkedConvert('variant', (v) => v as String),
        quantity: $checkedConvert('quantity', (v) => (v as num).toInt()),
      );
      return val;
    });

Map<String, dynamic> _$TaskItemToJson(TaskItem instance) => <String, dynamic>{
  'name': instance.name,
  'variant': instance.variant,
  'quantity': instance.quantity,
};
