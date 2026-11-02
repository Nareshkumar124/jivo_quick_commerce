import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/providers.dart';
import '../../../app/redirect.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/product_image.dart';
import '../../catalog/domain/catalog_models.dart';

/// How often the home banners advance; null turns auto-scroll off (tests).
final bannerAutoScrollProvider = Provider<Duration?>(
  (ref) => const Duration(seconds: 4),
);

/// Opens what a banner links to (`03 §2.5`).
void openBannerLink(BuildContext context, WidgetRef ref, BannerLink link) {
  switch (link) {
    case CategoryBannerLink(:final slug):
      context.push(Routes.category(slug));
    case CollectionBannerLink(:final slug):
      context.push(Routes.collection(slug));
    case ProductBannerLink(:final slug):
      context.push(Routes.product(slug));
    case UrlBannerLink(:final url):
      ref.read(urlOpenerProvider).open(url);
    case NoBannerLink():
      break;
  }
}

/// Admin-managed banners, auto-scrolling (`03 §2.5`). Auto-scroll stops
/// when the system asks for reduced motion.
class BannerCarousel extends ConsumerStatefulWidget {
  const BannerCarousel({required this.banners, super.key});

  final List<HomeBanner> banners;

  @override
  ConsumerState<BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends ConsumerState<BannerCarousel> {
  final _controller = PageController();
  Timer? _timer;
  int _page = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _timer?.cancel();
    final interval = ref.read(bannerAutoScrollProvider);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (interval != null && !reduceMotion && widget.banners.length > 1) {
      _timer = Timer.periodic(interval, (_) => _advance());
    }
  }

  void _advance() {
    if (!_controller.hasClients) return;
    final next = (_page + 1) % widget.banners.length;
    _controller.animateToPage(
      next,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final banners = widget.banners;
    return Column(
      children: [
        SizedBox(
          height: 150,
          child: PageView.builder(
            key: const Key('banner-carousel'),
            controller: _controller,
            itemCount: banners.length,
            onPageChanged: (page) => setState(() => _page = page),
            itemBuilder: (context, i) {
              final banner = banners[i];
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: JivoSpacing.gutter,
                ),
                child: Semantics(
                  button: banner.link is! NoBannerLink,
                  label: l10n.bannerSemantics(banner.title),
                  excludeSemantics: true,
                  child: Material(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(JivoRadii.lg),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => openBannerLink(context, ref, banner.link),
                      child: banner.imageUrl == null
                          ? Padding(
                              padding: const EdgeInsets.all(JivoSpacing.lg),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  banner.title,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    color: theme.colorScheme.onPrimaryContainer,
                                  ),
                                ),
                              ),
                            )
                          : ProductImage(
                              url: banner.imageUrl,
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (banners.length > 1)
          ExcludeSemantics(
            child: Padding(
              padding: const EdgeInsets.only(top: JivoSpacing.sm),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < banners.length; i++)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _page ? 16 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: i == _page
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
