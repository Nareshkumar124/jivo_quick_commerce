// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/reward.dart';
import 'package:jivo_api/src/model/reward_history_entry.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'rewards.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class Rewards {
  /// Returns a new [Rewards] instance.
  Rewards({required this.available, required this.history});

  /// AVAILABLE rewards (soonest expiry first), then CLAIMED ones. [] when none.
  @JsonKey(name: r'available', required: true, includeIfNull: false)
  final List<Reward> available;

  /// Newest first, at most the latest 100 entries: rewards earned, claimed, used and expired, and the volume-offer free cartons of each delivered order.
  @JsonKey(name: r'history', required: true, includeIfNull: false)
  final List<RewardHistoryEntry> history;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Rewards &&
          other.available == available &&
          other.history == history;

  @override
  int get hashCode => available.hashCode + history.hashCode;

  factory Rewards.fromJson(Map<String, dynamic> json) =>
      _$RewardsFromJson(json);

  Map<String, dynamic> toJson() => _$RewardsToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
