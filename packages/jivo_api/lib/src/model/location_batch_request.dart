// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/location_point_request.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'location_batch_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class LocationBatchRequest {
  /// Returns a new [LocationBatchRequest] instance.
  LocationBatchRequest({required this.points});

  /// 1 to `max_batch` points (default 50), any order. Send a batch again unchanged if its response was lost: points already stored are skipped.
  @JsonKey(name: r'points', required: true, includeIfNull: false)
  final List<LocationPointRequest> points;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocationBatchRequest && other.points == points;

  @override
  int get hashCode => points.hashCode;

  factory LocationBatchRequest.fromJson(Map<String, dynamic> json) =>
      _$LocationBatchRequestFromJson(json);

  Map<String, dynamic> toJson() => _$LocationBatchRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
