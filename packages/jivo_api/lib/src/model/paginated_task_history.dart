// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/task_history_item.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'paginated_task_history.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class PaginatedTaskHistory {
  /// Returns a new [PaginatedTaskHistory] instance.
  PaginatedTaskHistory({
    required this.count,

    required this.next,

    required this.previous,

    required this.results,
  });

  /// All entries, whatever `before_id`.
  @JsonKey(name: r'count', required: true, includeIfNull: false)
  final int count;

  /// Older entries (carries `before_id`).
  @JsonKey(name: r'next', required: true, includeIfNull: true)
  final String? next;

  /// Always null.
  @JsonKey(name: r'previous', required: true, includeIfNull: true)
  final String? previous;

  @JsonKey(name: r'results', required: true, includeIfNull: false)
  final List<TaskHistoryItem> results;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaginatedTaskHistory &&
          other.count == count &&
          other.next == next &&
          other.previous == previous &&
          other.results == results;

  @override
  int get hashCode =>
      count.hashCode +
      (next == null ? 0 : next.hashCode) +
      (previous == null ? 0 : previous.hashCode) +
      results.hashCode;

  factory PaginatedTaskHistory.fromJson(Map<String, dynamic> json) =>
      _$PaginatedTaskHistoryFromJson(json);

  Map<String, dynamic> toJson() => _$PaginatedTaskHistoryToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
