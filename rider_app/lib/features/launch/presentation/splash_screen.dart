import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/brand.dart';
import '../../../app/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/jivo_wordmark.dart';
import '../../auth/domain/rider_account.dart';
import '../../auth/presentation/rider_account_controller.dart';
import 'blocking_message.dart';
import 'launch_controller.dart';

/// Splash (04 §4 screen 1): loads `config/app`, then, for a restored session,
/// `GET /me/` for `rider_status`. The router moves on by itself; this screen
/// only shows progress, or an error with a Retry button. It never continues
/// without the config (login needs `terms_version` and the policy links).
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    final launch = ref.read(launchControllerProvider.notifier);
    if (ref.read(launchControllerProvider).config == null) await launch.load();
    if (!mounted || ref.read(launchControllerProvider).config == null) return;

    final signedIn = ref.read(sessionManagerProvider).isSignedIn;
    final account = ref.read(riderAccountControllerProvider);
    if (signedIn && account is! AccountLoaded) {
      await ref.read(riderAccountControllerProvider.notifier).load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final launch = ref.watch(launchControllerProvider);
    final account = ref.watch(riderAccountControllerProvider);
    final error = launch.config == null
        ? launch.error
        : (account is AccountLoadFailed ? account.error : null);

    if (error != null && !launch.loading) {
      // UX audit RA-02: only a network failure or timeout says "No
      // internet"; a server error must not send the rider to check data.
      final offline = isConnectivityError(error);
      return Scaffold(
        body: BlockingMessage(
          icon: offline ? Icons.wifi_off : Icons.cloud_off,
          title: offline ? l10n.splashErrorNoInternet : l10n.splashErrorServer,
          body: apiErrorMessage(JivoCoreLocalizations.of(context), error),
          actions: [
            FilledButton(
              key: const Key('splash-retry'),
              onPressed: _start,
              child: Text(l10n.retry),
            ),
          ],
        ),
      );
    }

    // Brand green with the white wordmark, continuing the native splash.
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: kJivoBrandGreen,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const JivoWordmark(
              key: Key('splash-logo'),
              height: 80,
              color: Colors.white,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.appTitle,
              style: theme.textTheme.headlineMedium?.copyWith(
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(color: Colors.white),
            const SizedBox(height: 16),
            Text(
              l10n.splashLoading,
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

/// A failure that never reached the server: no network, or a timeout.
bool isConnectivityError(ApiError error) =>
    error.code == ApiErrorCode.network || error.code == ApiErrorCode.timeout;
