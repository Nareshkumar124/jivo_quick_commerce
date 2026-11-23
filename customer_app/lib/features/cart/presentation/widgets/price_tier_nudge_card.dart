import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../../app/theme.dart';
import '../../../../l10n/generated/app_localizations.dart';

/// The volume-price "piggy" nudge at the top of the cart. A pale-mint card
/// with a green edge (home redesign) that slides in once, then the icon
/// pulses once. Text comes from the server's numbers via [headline] and
/// [detail]; [semanticsLabel] is the full sentence for TalkBack.
class PriceTierNudgeCard extends StatefulWidget {
  const PriceTierNudgeCard({
    required this.headline,
    required this.detail,
    required this.semanticsLabel,
    this.onAddMore,
    super.key,
  });

  final String headline;
  final String detail;
  final String semanticsLabel;
  final VoidCallback? onAddMore;

  @override
  State<PriceTierNudgeCard> createState() => _PriceTierNudgeCardState();
}

class _PriceTierNudgeCardState extends State<PriceTierNudgeCard>
    with SingleTickerProviderStateMixin {
  // 0..0.4 slide + scale (about 400 ms of 1000 ms), 0.45..1 icon pulse.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // Home redesign: pale mint with green text (was the gold gradient).
    final ink = scheme.onPrimaryContainer;
    final enter = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.4, curve: Curves.easeOutBack),
    );
    final slide = Tween(
      begin: const Offset(0, -0.4),
      end: Offset.zero,
    ).animate(enter);
    final scale = Tween(begin: 0.92, end: 1.0).animate(enter);
    final pulse = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.45, 1),
    );

    return Semantics(
      container: true,
      liveRegion: true,
      label: widget.semanticsLabel,
      child: Padding(
        padding: EdgeInsets.zero,
        child: FadeTransition(
          opacity: CurvedAnimation(
            parent: _controller,
            curve: const Interval(0, 0.3),
          ),
          child: SlideTransition(
            position: slide,
            child: ScaleTransition(
              scale: scale,
              child: Container(
                padding: const EdgeInsets.all(JivoSpacing.md),
                decoration: BoxDecoration(
                  color: context.customerColors.softTint,
                  borderRadius: BorderRadius.circular(JivoRadii.lg),
                  border: Border.all(
                    color: scheme.primary.withValues(alpha: 0.35),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        AnimatedBuilder(
                          animation: pulse,
                          builder: (context, child) => Transform.scale(
                            scale: 1 + 0.18 * math.sin(pulse.value * math.pi),
                            child: child,
                          ),
                          child: ExcludeSemantics(
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.savings_outlined,
                                color: scheme.primary,
                                size: 26,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: JivoSpacing.md),
                        Expanded(
                          child: ExcludeSemantics(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.headline,
                                  key: const Key('price-tier-headline'),
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: ink,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  widget.detail,
                                  key: const Key('price-tier-detail'),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: scheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (widget.onAddMore != null)
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: TextButton(
                          key: const Key('price-tier-add-more'),
                          style: TextButton.styleFrom(
                            foregroundColor: scheme.primary,
                            minimumSize: const Size(
                              kJivoMinTouchTarget,
                              kJivoMinTouchTarget,
                            ),
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w800,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                          onPressed: widget.onAddMore,
                          child: Text(l10n.priceTierAddMore),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
