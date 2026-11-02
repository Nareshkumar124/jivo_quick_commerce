import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/launch_state.dart';
import '../../../app/providers.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Three brand slides on first launch, skippable (`03 §2.1`).
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await ref.read(appFlagsProvider).markOnboardingSeen();
    ref.read(launchStateProvider).markOnboardingSeen();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final slides = [
      (
        Icons.local_shipping_outlined,
        l10n.onboardingTitle1,
        l10n.onboardingBody1,
      ),
      (Icons.verified_outlined, l10n.onboardingTitle2, l10n.onboardingBody2),
      (Icons.location_on_outlined, l10n.onboardingTitle3, l10n.onboardingBody3),
    ];
    final last = _page == slides.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _finish,
                child: Text(l10n.onboardingSkip),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (page) => setState(() => _page = page),
                children: [
                  for (final (icon, title, body) in slides)
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(JivoSpacing.xl),
                      child: Column(
                        children: [
                          const SizedBox(height: JivoSpacing.xxl),
                          Icon(
                            icon,
                            size: 96,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(height: JivoSpacing.xl),
                          Semantics(
                            header: true,
                            child: Text(
                              title,
                              style: theme.textTheme.headlineSmall,
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: JivoSpacing.md),
                          Text(
                            body,
                            style: theme.textTheme.bodyLarge,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(JivoSpacing.gutter),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: last
                      ? _finish
                      : () => _controller.nextPage(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut,
                        ),
                  child: Text(
                    last ? l10n.onboardingStart : l10n.onboardingNext,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
