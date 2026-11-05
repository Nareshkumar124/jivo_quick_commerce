import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/routes.dart';
import '../../../app/theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/rider_account_controller.dart';
import '../../location/domain/location_service_client.dart';
import '../../permissions/domain/permission_gate.dart';
import '../../permissions/presentation/permissions_gate_controller.dart';
import '../../task/domain/task_rules.dart';
import '../../task/domain/task_status.dart';
import '../../task/presentation/task_flow_controller.dart';
import '../../task/presentation/task_providers.dart';
import '../domain/today_summary.dart';
import 'home_providers.dart';
import 'shift_controller.dart';

// Rider home widgets, to `design/screens/rider/home.md` (UX audit RD-01)
// with the `rider.tokens.json` colours (RD-05).

/// The localised persistent "You're online" notification (04 §2.3).
OnlineNotificationText onlineNotificationText(AppLocalizations l10n) =>
    OnlineNotificationText(
      title: l10n.onlineNotificationTitle,
      body: l10n.onlineNotificationText,
      channelName: l10n.onlineChannelName,
      channelDescription: l10n.onlineChannelDescription,
    );

/// Goes online with a haptic on success (home spec §2).
Future<void> goOnlineFromHome(WidgetRef ref, AppLocalizations l10n) async {
  final ok = await ref
      .read(shiftControllerProvider.notifier)
      .goOnline(onlineNotificationText(l10n));
  if (ok) {
    unawaited(HapticFeedback.mediumImpact());
    ref.invalidate(todaySummaryProvider);
  }
}

Future<void> goOfflineFromHome(WidgetRef ref) async {
  final ok = await ref.read(shiftControllerProvider.notifier).goOffline();
  if (ok) {
    unawaited(HapticFeedback.mediumImpact());
    ref.invalidate(todaySummaryProvider);
  }
}

// ------------------------------------------------------------- §3 status

/// The status card (§3): the state always in words; the dot is decoration.
class ShiftStatusCard extends ConsumerWidget {
  const ShiftStatusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = RiderColors.of(context);
    final theme = Theme.of(context);
    final state = ref.watch(shiftControllerProvider);
    final summary = ref.watch(todaySummaryProvider).value;
    final controller = ref.read(shiftControllerProvider.notifier);

    if (!state.synced) {
      return Container(
        key: const Key('shift-card-loading'),
        height: 72,
        decoration: BoxDecoration(
          color: colors.neutralContainer,
          borderRadius: BorderRadius.circular(12),
        ),
      );
    }

    final online = state.isOnline || state.phase == ShiftPhase.goingOffline;
    final autoOffline = !online && state.problem == ShiftProblem.autoOffline;
    final prepaidOnly =
        online && (state.prepaidOnly || (summary?.limitReached ?? false));
    final store = summary?.homeStoreName;

    final BoxDecoration decoration;
    final Widget leading;
    final String title;
    final String body;
    if (autoOffline) {
      decoration = colors.codDecoration();
      leading = Icon(Icons.location_off, color: colors.codBorder, size: 24);
      title = l10n.shiftAutoOfflineTitle;
      body = l10n.shiftAutoOfflineBody;
    } else if (prepaidOnly) {
      decoration = colors.codDecoration();
      leading = _Dot(color: colors.codBorder, filled: true);
      title = l10n.shiftOnlinePrepaidTitle;
      body = l10n.shiftOnlinePrepaidBody;
    } else if (online) {
      decoration = BoxDecoration(
        color: colors.surface,
        border: Border.all(
          color: colors.onlineBg,
          width: RiderColors.borderWidth,
        ),
        borderRadius: BorderRadius.circular(12),
      );
      leading = _Dot(color: colors.onlineBg, filled: true);
      title = l10n.shiftOnlineTitle;
      body = store == null
          ? l10n.shiftOnlineBody
          : l10n.shiftOnlineBodyStore(store);
    } else {
      decoration = BoxDecoration(
        color: colors.neutralContainer,
        borderRadius: BorderRadius.circular(12),
      );
      leading = _Dot(color: colors.textSecondary, filled: false);
      title = l10n.shiftOfflineTitle;
      body = l10n.shiftOfflineBody;
    }

    return Container(
      key: const Key('shift-card'),
      padding: const EdgeInsets.all(16),
      decoration: decoration,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: ExcludeSemantics(child: leading),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Semantics(
              liveRegion: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    key: const Key('shift-status'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    body,
                    key: const Key('shift-status-body'),
                    maxLines: autoOffline ? null : 2,
                    overflow: autoOffline ? null : TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (autoOffline)
            IconButton(
              key: const Key('shift-auto-offline-close'),
              tooltip: l10n.dismiss,
              onPressed: controller.dismissProblem,
              icon: const Icon(Icons.close),
            ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color, required this.filled});

  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) => Container(
    width: 12,
    height: 12,
    margin: const EdgeInsets.only(top: 4),
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: filled ? color : null,
      border: Border.all(color: color, width: 2),
    ),
  );
}

// -------------------------------------------------------------- §4 guard

enum HomeGuard {
  notActive,

  /// `DOCUMENTS_NOT_APPROVED`: a document needs a new upload.
  documents,
  permissions,
  gps,
  tooFar,
  taskActive,
  network,

  /// Anything else that went wrong (service did not start, an unexpected
  /// server refusal): same card, "Try again".
  other,
}

/// Which guard card the shift state calls for (§4), or null.
HomeGuard? homeGuardOf(ShiftState state) {
  final problem = state.problem;
  final code = state.error?.code;
  final reason = ShiftRefusal.of(state.error);
  return switch (problem) {
    null || ShiftProblem.autoOffline => null,
    ShiftProblem.permissionsMissing when state.missingStep == GateStep.gps =>
      HomeGuard.gps,
    ShiftProblem.permissionsMissing => HomeGuard.permissions,
    ShiftProblem.locationUnavailable => HomeGuard.gps,
    ShiftProblem.taskActive => HomeGuard.taskActive,
    ShiftProblem.server when reason == ShiftRefusal.riderNotActive =>
      HomeGuard.notActive,
    ShiftProblem.server when reason == ShiftRefusal.documentsNotApproved =>
      HomeGuard.documents,
    ShiftProblem.server
        when reason == ShiftRefusal.tooFarFromStore ||
            code == ApiErrorCode.outsideGeofence =>
      HomeGuard.tooFar,
    ShiftProblem.server when code == ApiErrorCode.permissionDenied =>
      HomeGuard.notActive,
    ShiftProblem.server || ShiftProblem.endNotConfirmed
        when code == ApiErrorCode.network || code == ApiErrorCode.timeout =>
      HomeGuard.network,
    ShiftProblem.endNotConfirmed => HomeGuard.network,
    ShiftProblem.server || ShiftProblem.serviceFailed => HomeGuard.other,
  };
}

/// Guards that disable "Go online" until fixed (§2). The permission guards
/// clear themselves when the rider comes back from Settings with the gate
/// passing.
bool guardBlocksGoingOnline(HomeGuard? guard) =>
    guard == HomeGuard.notActive ||
    guard == HomeGuard.documents ||
    guard == HomeGuard.permissions ||
    guard == HomeGuard.gps;

class GuardCard extends ConsumerWidget {
  const GuardCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(shiftControllerProvider);
    final guard = homeGuardOf(state);
    if (guard == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final colors = RiderColors.of(context);
    final theme = Theme.of(context);
    final controller = ref.read(shiftControllerProvider.notifier);
    final summary = ref.watch(todaySummaryProvider).value;
    final store = summary?.homeStoreName ?? l10n.homeYourStore;
    final error = state.error;

    final (IconData icon, String title, String? body) = switch (guard) {
      HomeGuard.notActive => (
        Icons.badge,
        l10n.guardNotActiveTitle,
        l10n.guardNotActiveBody,
      ),
      HomeGuard.documents => (
        Icons.description,
        l10n.guardDocumentsTitle,
        l10n.guardDocumentsBody,
      ),
      HomeGuard.permissions => (
        Icons.location_disabled,
        l10n.guardPermissionsTitle,
        l10n.guardPermissionsBody,
      ),
      HomeGuard.gps => (Icons.gps_off, l10n.guardGpsTitle, l10n.guardGpsBody),
      HomeGuard.tooFar => (
        Icons.wrong_location,
        l10n.guardTooFarTitle,
        _tooFarBody(l10n, error, store),
      ),
      HomeGuard.taskActive => (
        Icons.two_wheeler,
        l10n.guardTaskActiveTitle,
        null,
      ),
      HomeGuard.network => (
        Icons.wifi_off,
        l10n.guardNetworkTitle,
        l10n.guardNetworkBody,
      ),
      HomeGuard.other => (
        Icons.error_outline,
        state.problem == ShiftProblem.serviceFailed
            ? l10n.shiftServiceFailed
            : (error == null
                  ? l10n.shiftServerError
                  : apiErrorMessage(JivoCoreLocalizations.of(context), error)),
        null,
      ),
    };

    final storeLocation = summary?.homeStoreLocation;
    final (String? label, VoidCallback? action) = switch (guard) {
      HomeGuard.notActive => (
        l10n.shiftSeeStatus,
        () => ref.read(riderAccountControllerProvider.notifier).load(),
      ),
      HomeGuard.documents => (
        l10n.guardDocumentsAction,
        () => context.push(Routes.profileDocuments),
      ),
      HomeGuard.permissions => (
        l10n.shiftFixPermissions,
        () => context.push(Routes.permissions),
      ),
      HomeGuard.gps => (
        l10n.guardGpsAction,
        () => ref
            .read(permissionsGateControllerProvider.notifier)
            .fix(const GateItem(GateStep.gps, done: false)),
      ),
      HomeGuard.tooFar =>
        storeLocation == null
            ? (null, null)
            : (
                l10n.guardNavigateToStore,
                () => ref
                    .read(navigationLauncherProvider)
                    .navigateTo(storeLocation, label: store),
              ),
      HomeGuard.taskActive => (
        l10n.currentTaskContinueOrder,
        () => context.go(Routes.task),
      ),
      HomeGuard.network => (
        l10n.retry,
        state.endPending
            ? controller.retryEnd
            : () => goOnlineFromHome(ref, l10n),
      ),
      HomeGuard.other => (l10n.retry, controller.dismissProblem),
    };

    return Semantics(
      liveRegion: true,
      // A non-uniform border can't take a radius, so the card is clipped.
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            key: const Key('shift-problem'),
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border(
                left: BorderSide(color: colors.danger, width: 2),
                top: BorderSide(color: colors.neutralContainer),
                right: BorderSide(color: colors.neutralContainer),
                bottom: BorderSide(color: colors.neutralContainer),
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, color: colors.danger, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            key: const Key('shift-problem-text'),
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: colors.textPrimary,
                            ),
                          ),
                          if (body != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              body,
                              key: const Key('shift-problem-body'),
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: colors.textPrimary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                if (label != null) ...[
                  const SizedBox(height: 12),
                  FilledButton(
                    key: const Key('shift-problem-action'),
                    onPressed: action,
                    child: Text(label),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _tooFarBody(
    AppLocalizations l10n,
    ApiError? error,
    String store,
  ) {
    final distance = error?.details['distance_m'];
    final radius = error?.details['radius_m'];
    if (distance is num && radius is num) {
      return l10n.guardTooFarBody(formatKm(distance), store, formatKm(radius));
    }
    return l10n.guardTooFarBodyNoDistance(store);
  }
}

// ------------------------------------------------------- §2 online control

/// The bottom-pinned online control (§2): one full-width 72 dp button,
/// never a `Switch`.
class OnlineControl extends ConsumerWidget {
  const OnlineControl({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = RiderColors.of(context);
    final state = ref.watch(shiftControllerProvider);
    const minimumSize = Size.fromHeight(kRiderOnlineControlHeight);
    const label = TextStyle(fontSize: 22, fontWeight: FontWeight.w700);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );

    Widget spinner(Color color) => SizedBox.square(
      dimension: 24,
      child: CircularProgressIndicator(strokeWidth: 3, color: color),
    );

    if (!state.synced) {
      return Container(
        key: const Key('shift-toggle-loading'),
        height: kRiderOnlineControlHeight,
        decoration: BoxDecoration(
          color: colors.neutralContainer,
          borderRadius: BorderRadius.circular(12),
        ),
      );
    }

    if (state.phase == ShiftPhase.online ||
        state.phase == ShiftPhase.goingOffline) {
      final busy = state.phase == ShiftPhase.goingOffline;
      return OutlinedButton.icon(
        key: const Key('shift-toggle'),
        style: OutlinedButton.styleFrom(
          minimumSize: minimumSize,
          textStyle: label,
          shape: shape,
          backgroundColor: colors.surface,
          foregroundColor: colors.textPrimary,
          side: BorderSide(
            color: colors.textPrimary,
            width: RiderColors.borderWidth,
          ),
        ),
        onPressed: busy ? null : () => goOfflineFromHome(ref),
        icon: busy
            ? spinner(colors.textPrimary)
            : const Icon(Icons.power_off, size: 28),
        label: Text(busy ? l10n.shiftGoingOffline : l10n.shiftGoOffline),
      );
    }

    final busy = state.phase == ShiftPhase.goingOnline;
    final guard = homeGuardOf(state);
    final blocked = guardBlocksGoingOnline(guard);
    final button = FilledButton.icon(
      key: const Key('shift-toggle'),
      style: FilledButton.styleFrom(
        minimumSize: minimumSize,
        textStyle: label,
        shape: shape,
        backgroundColor: colors.onlineBg,
        foregroundColor: colors.onlineFg,
        disabledBackgroundColor: colors.onlineBg.withValues(
          alpha: busy ? 1 : 0.38,
        ),
        disabledForegroundColor: colors.onlineFg,
      ),
      onPressed: busy || blocked ? null : () => goOnlineFromHome(ref, l10n),
      icon: busy
          ? spinner(colors.onlineFg)
          : const Icon(Icons.power_settings_new, size: 28),
      label: Text(busy ? l10n.shiftGoingOnline : l10n.shiftGoOnline),
    );
    return blocked
        ? Semantics(hint: l10n.guardBlockedHint, child: button)
        : button;
  }
}

// ---------------------------------------------------- §7 current task card

/// Replaces the online control while a task is active (§7).
class CurrentTaskCard extends ConsumerWidget {
  const CurrentTaskCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final task = ref.watch(taskFlowControllerProvider).task;
    if (task == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final colors = RiderColors.of(context);
    final theme = Theme.of(context);
    final step = switch (task.status) {
      TaskStatus.assigned => l10n.taskStepGoToStore,
      TaskStatus.atStore => l10n.taskStepPickup,
      TaskStatus.pickedUp => l10n.taskStepGoToCustomer,
      TaskStatus.atCustomer => l10n.taskStepDeliver,
      TaskStatus.failed || TaskStatus.returning => l10n.taskStepReturn,
      _ => l10n.taskStepOther,
    };
    final locality = task.dropLocality;
    final stepLine = locality == null ? step : '$step · $locality';
    final cod = task.isCod;
    final amount = codAmountText(task);
    final chip = cod
        ? (amount == null ? l10n.chipCod : l10n.chipCodAmount(amount))
        : l10n.chipPrepaid;

    return Semantics(
      label: l10n.currentTaskSemantics(task.orderNumber, step),
      container: true,
      child: Container(
        key: const Key('current-task-card'),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.textPrimary, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.taskOrderNumber(task.orderNumber),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  key: const Key('current-task-payment'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: cod
                      ? colors.codDecoration(radius: 8)
                      : BoxDecoration(
                          color: colors.neutralContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                  child: Text(
                    chip,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              stepLine,
              key: const Key('current-task-step'),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const Key('current-task-continue'),
              style: FilledButton.styleFrom(
                backgroundColor: colors.onlineBg,
                foregroundColor: colors.onlineFg,
              ),
              onPressed: () => context.go(Routes.task),
              icon: const Icon(Icons.arrow_forward),
              label: Text(l10n.currentTaskContinue),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------- §5 today tiles

/// Today: delivered, earned, online time, cash in hand (§5). Server values
/// only; an unknown value is "–", never 0.
class TodaySummaryTiles extends ConsumerWidget {
  const TodaySummaryTiles({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(todaySummaryProvider);
    final failed = async.hasError && !async.hasValue;
    final loading = async.isLoading && !async.hasValue;
    final summary = async.value;

    String? money(String? amount) => tryFormatRupees(amount);
    final tiles = [
      _TileData(
        key: 'today-delivered',
        label: l10n.todayDelivered,
        value: summary?.deliveredCount?.toString(),
      ),
      _TileData(
        key: 'today-earned',
        label: l10n.todayEarned,
        value: money(summary?.earnedToday),
        route: Routes.earnings,
        semanticsOpens: l10n.todayOpensEarnings,
      ),
      _TileData(
        key: 'today-online',
        label: l10n.todayOnline,
        value: summary?.onlineSeconds == null
            ? null
            : formatOnlineTime(summary!.onlineSeconds!),
      ),
      _TileData(
        key: 'today-cash',
        label: l10n.todayCash,
        value: money(summary?.cashInHand),
        route: Routes.cash,
        semanticsOpens: l10n.todayOpensCash,
      ),
    ];

    final singleColumn = MediaQuery.textScalerOf(context).scale(1) > 1.5;
    Widget tile(_TileData data) => _Tile(data: data, loading: loading);
    final grid = singleColumn
        ? Column(children: [for (final t in tiles) tile(t)])
        : Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: tile(tiles[0])),
                  Expanded(child: tile(tiles[1])),
                ],
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: tile(tiles[2])),
                  Expanded(child: tile(tiles[3])),
                ],
              ),
            ],
          );

    return Column(
      key: const Key('today-summary'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.todayTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (failed)
              TextButton(
                key: const Key('today-retry'),
                onPressed: () => ref.invalidate(todaySummaryProvider),
                child: Text(l10n.retry),
              ),
          ],
        ),
        const SizedBox(height: 4),
        grid,
      ],
    );
  }
}

class _TileData {
  const _TileData({
    required this.key,
    required this.label,
    required this.value,
    this.route,
    this.semanticsOpens,
  });

  final String key;
  final String label;
  final String? value;
  final String? route;
  final String? semanticsOpens;
}

class _Tile extends StatelessWidget {
  const _Tile({required this.data, required this.loading});

  final _TileData data;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = RiderColors.of(context);
    final value = data.value;
    final shown = loading ? '' : (value ?? '–');
    final semanticValue = loading ? '' : (value ?? l10n.todayNotAvailable);
    final route = data.route;
    final content = Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data.label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            shown,
            key: Key('${data.key}-value'),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Semantics(
        label: data.semanticsOpens == null
            ? '${data.label} $semanticValue'
            : '${data.label} $semanticValue, ${data.semanticsOpens}',
        button: route != null,
        excludeSemantics: true,
        child: Material(
          key: Key(data.key),
          color: colors.neutralContainer,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: route == null ? null : () => context.push(route),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 88),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------ §6 deposit banner

/// "Deposit cash" when the server sends `limit_reached` (§6). The cash
/// limit never blocks going online (04 §2.3): prepaid orders only.
class CashLimitBanner extends ConsumerWidget {
  const CashLimitBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(todaySummaryProvider).value;
    if (summary == null || !summary.limitReached) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    final colors = RiderColors.of(context);
    final limit = tryFormatRupees(summary.cashLimit) ?? '–';
    return Container(
      key: const Key('cash-limit-banner'),
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      decoration: colors.codDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.warning, color: colors.codBorder, size: 24),
              const SizedBox(width: 8),
              Text(
                l10n.cashDepositTitle,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: colors.codText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l10n.cashDepositBody(limit),
            style: TextStyle(fontSize: 16, color: colors.codText),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            key: const Key('cash-limit-how'),
            onPressed: () => _showHowTo(context),
            child: Text(l10n.homeHowToDeposit),
          ),
        ],
      ),
    );
  }

  static Future<void> _showHowTo(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return showModalBottomSheet<void>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.homeHowToDepositBody,
                style: Theme.of(sheet).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('cash-limit-see-ledger'),
                onPressed: () {
                  Navigator.of(sheet).pop();
                  context.push(Routes.cash);
                },
                child: Text(l10n.homeSeeCashLedger),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The home app bar title: "Hi, Ravi" (first word, 16 characters max), or
/// "Jivo Rider" without a name (§9).
String homeGreeting(AppLocalizations l10n, String? fullName) {
  final first = (fullName ?? '').trim().split(RegExp(r'\s+')).first;
  if (first.isEmpty) return l10n.appTitle;
  final short = first.length > 16 ? '${first.substring(0, 16)}…' : first;
  return l10n.homeGreeting(short);
}
