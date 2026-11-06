// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_earnings.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$TaskEarningsCWProxy {
  TaskEarnings total(String total);

  TaskEarnings lines(List<EarningLine> lines);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `TaskEarnings(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// TaskEarnings(...).copyWith(id: 12, name: "My name")
  /// ````
  TaskEarnings call({String total, List<EarningLine> lines});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfTaskEarnings.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfTaskEarnings.copyWith.fieldName(...)`
class _$TaskEarningsCWProxyImpl implements _$TaskEarningsCWProxy {
  const _$TaskEarningsCWProxyImpl(this._value);

  final TaskEarnings _value;

  @override
  TaskEarnings total(String total) => this(total: total);

  @override
  TaskEarnings lines(List<EarningLine> lines) => this(lines: lines);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `TaskEarnings(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// TaskEarnings(...).copyWith(id: 12, name: "My name")
  /// ````
  TaskEarnings call({
    Object? total = const $CopyWithPlaceholder(),
    Object? lines = const $CopyWithPlaceholder(),
  }) {
    return TaskEarnings(
      total: total == const $CopyWithPlaceholder()
          ? _value.total
          // ignore: cast_nullable_to_non_nullable
          : total as String,
      lines: lines == const $CopyWithPlaceholder()
          ? _value.lines
          // ignore: cast_nullable_to_non_nullable
          : lines as List<EarningLine>,
    );
  }
}

extension $TaskEarningsCopyWith on TaskEarnings {
  /// Returns a callable class that can be used as follows: `instanceOfTaskEarnings.copyWith(...)` or like so:`instanceOfTaskEarnings.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$TaskEarningsCWProxy get copyWith => _$TaskEarningsCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TaskEarnings _$TaskEarningsFromJson(Map<String, dynamic> json) =>
    $checkedCreate('TaskEarnings', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['total', 'lines']);
      final val = TaskEarnings(
        total: $checkedConvert('total', (v) => v as String),
        lines: $checkedConvert(
          'lines',
          (v) => (v as List<dynamic>)
              .map((e) => EarningLine.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
      );
      return val;
    });

Map<String, dynamic> _$TaskEarningsToJson(TaskEarnings instance) =>
    <String, dynamic>{
      'total': instance.total,
      'lines': instance.lines.map((e) => e.toJson()).toList(),
    };
