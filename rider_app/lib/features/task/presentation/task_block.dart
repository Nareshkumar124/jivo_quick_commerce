import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether a delivery task in progress blocks logout and going offline
/// (agent rule 7). Set by the task flow controller; read by logout and the
/// online toggle. A separate provider with no dependencies, so the account
/// controller can read it without a provider cycle (the task controller
/// depends on the account).
final taskBlocksGoingOfflineProvider =
    NotifierProvider<TaskBlockNotifier, bool>(TaskBlockNotifier.new);

class TaskBlockNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool blocked) {
    if (state != blocked) state = blocked;
  }
}
