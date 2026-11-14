import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/product_image.dart';
import '../../catalog/domain/catalog_models.dart';
import 'banner_carousel.dart';

/// Opens [banner] full screen (`03 §2.5`).
Future<void> showBannerViewer(BuildContext context, HomeBanner banner) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => BannerViewer(banner: banner),
      ),
    );

/// Full-screen banner: black background, pinch to zoom and pan, a close
/// button, swipe down or back to close, and a button for the banner's link.
class BannerViewer extends ConsumerStatefulWidget {
  const BannerViewer({required this.banner, super.key});

  final HomeBanner banner;

  @override
  ConsumerState<BannerViewer> createState() => _BannerViewerState();
}

class _BannerViewerState extends ConsumerState<BannerViewer> {
  final _transform = TransformationController();
  double _drag = 0;
  bool _closing = false;
  Offset _tapAt = Offset.zero;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  bool get _zoomed => _transform.value.getMaxScaleOnAxis() > 1.01;

  void _resetDrag() {
    if (_drag != 0) setState(() => _drag = 0);
    _closing = false;
  }

  /// Double tap: zoom to 2.5x around the tapped point, or back to 1x.
  void _toggleZoom() {
    if (_zoomed) {
      _transform.value = Matrix4.identity();
      return;
    }
    const scale = 2.5;
    _transform.value = Matrix4.identity()
      ..translateByDouble(
        -_tapAt.dx * (scale - 1),
        -_tapAt.dy * (scale - 1),
        0,
        1,
      )
      ..scaleByDouble(scale, scale, 1, 1);
  }

  void _open() {
    final link = widget.banner.link;
    final navigator = Navigator.of(context);
    final below = navigator.context;
    navigator.pop();
    if (below.mounted) openBannerLink(below, ref, link);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final banner = widget.banner;
    final link = banner.link;
    final label = link is ReferralBannerLink ? l10n.referNow : l10n.shopNow;
    return Scaffold(
      key: const Key('banner-viewer'),
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            // Taps only. Swipe-down is read from the InteractiveViewer's own
            // scale gestures, so no second recognizer fights pinch zoom.
            behavior: HitTestBehavior.opaque,
            onDoubleTapDown: (d) => _tapAt = d.localPosition,
            onDoubleTap: _toggleZoom,
            child: Transform.translate(
              offset: Offset(0, _drag.clamp(0, 400).toDouble()),
              child: InteractiveViewer(
                key: const Key('banner-viewer-zoom'),
                transformationController: _transform,
                minScale: 1,
                maxScale: 5,
                onInteractionStart: (d) {
                  _closing = d.pointerCount == 1 && !_zoomed;
                },
                onInteractionUpdate: (d) {
                  if (d.pointerCount > 1 || _zoomed) {
                    _closing = false;
                    _resetDrag();
                  } else if (_closing) {
                    setState(() => _drag += d.focalPointDelta.dy);
                  }
                },
                onInteractionEnd: (d) {
                  if (_closing &&
                      (_drag > 120 || d.velocity.pixelsPerSecond.dy > 800)) {
                    Navigator.of(context).maybePop();
                  }
                  _resetDrag();
                },
                child: Center(
                  child: Semantics(
                    image: true,
                    label: banner.title,
                    child: banner.imageUrl == null
                        ? Padding(
                            padding: const EdgeInsets.all(JivoSpacing.lg),
                            child: Text(
                              banner.title,
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(color: Colors.white),
                            ),
                          )
                        : ProductImage(
                            url: banner.imageUrl,
                            fit: BoxFit.contain,
                          ),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: IconButton(
                key: const Key('banner-viewer-close'),
                tooltip: l10n.closeBanner,
                color: Colors.white,
                iconSize: 28,
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
          ),
          if (link is! NoBannerLink)
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.all(JivoSpacing.gutter),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      key: const Key('banner-viewer-action'),
                      onPressed: _open,
                      child: Text(label),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
