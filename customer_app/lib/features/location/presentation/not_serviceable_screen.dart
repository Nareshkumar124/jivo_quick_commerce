import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/redirect.dart';
import '../../../app/repositories.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/state_views.dart';
import 'location_flow.dart';

/// "We're not in your area yet" with Notify me and Try another address
/// (`03 §2.3`).
class NotServiceableScreen extends ConsumerStatefulWidget {
  const NotServiceableScreen({this.args, super.key});

  /// Null when opened without a location (e.g. a restored route).
  final NotServiceableArgs? args;

  @override
  ConsumerState<NotServiceableScreen> createState() =>
      _NotServiceableScreenState();
}

class _NotServiceableScreenState extends ConsumerState<NotServiceableScreen> {
  bool _busy = false;
  bool _done = false;

  Future<void> _notify() async {
    final location = widget.args?.location;
    if (location == null) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(serviceabilityRepositoryProvider)
          .notifyMe(location.point, addressText: location.subtitle);
      if (mounted) setState(() => _done = true);
    } catch (error) {
      if (mounted) {
        showMessage(context, describeErrorWithDetails(context, error));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _tryAnother() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.location);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final location = widget.args?.location;
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(JivoSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.wrong_location_outlined,
                size: 64,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: JivoSpacing.lg),
              Semantics(
                header: true,
                child: Text(
                  l10n.notServiceableTitle,
                  style: theme.textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
              ),
              if (location != null) ...[
                const SizedBox(height: JivoSpacing.sm),
                Text(
                  location.subtitle ??
                      '${location.title} · ${formatCoordinate(location.point.lat)}, '
                          '${formatCoordinate(location.point.lng)}',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: JivoSpacing.md),
              Text(l10n.notServiceableBody, textAlign: TextAlign.center),
              const SizedBox(height: JivoSpacing.xl),
              if (_done)
                Semantics(
                  liveRegion: true,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: context.jivoColors.success,
                      ),
                      const SizedBox(width: JivoSpacing.sm),
                      Flexible(
                        child: Text(
                          l10n.notifyMeDone,
                          key: const Key('notify-done'),
                        ),
                      ),
                    ],
                  ),
                )
              else
                BusyButton(
                  label: l10n.notifyMe,
                  busy: _busy,
                  onPressed: location == null ? null : _notify,
                ),
              const SizedBox(height: JivoSpacing.md),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _tryAnother,
                  child: Text(l10n.tryAnotherAddress),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
