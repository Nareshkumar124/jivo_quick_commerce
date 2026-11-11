import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../l10n/generated/app_localizations.dart';
import '../connectivity/connectivity.dart';

/// Wraps every screen and shows "No internet connection" on top while the
/// device is offline, or after requests keep failing for lack of a
/// connection (`03 §2.1`, CA-02). Installed via `MaterialApp.builder`.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offline = ref.watch(connectionLostProvider);
    final theme = Theme.of(context);
    return Column(
      children: [
        if (offline)
          Material(
            color: theme.colorScheme.inverseSurface,
            child: SafeArea(
              bottom: false,
              child: Semantics(
                liveRegion: true,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: JivoSpacing.gutter,
                    vertical: JivoSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.wifi_off,
                        size: 18,
                        color: theme.colorScheme.onInverseSurface,
                      ),
                      const SizedBox(width: JivoSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppLocalizations.of(context).offlineBanner,
                              style: TextStyle(
                                color: theme.colorScheme.onInverseSurface,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              AppLocalizations.of(context).offlineBannerHint,
                              style: TextStyle(
                                color: theme.colorScheme.onInverseSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        Expanded(
          child: offline
              ? MediaQuery.removePadding(
                  context: context,
                  removeTop: true,
                  child: child,
                )
              : child,
        ),
      ],
    );
  }
}
