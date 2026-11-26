import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Back for a screen that can be opened with nothing behind it: after
/// `go(...)` (order placed, "View order", a rating sent) the screen is the
/// only page, so Android back would close the app. When its page is the
/// first one, back (system or app bar) goes to [fallback] instead; when
/// something is behind it, back pops as normal.
///
/// Wrapped round the order screens in the router, so every way in is
/// covered (2026-11-26: "When I go back from an order, the app closes").
class ParentBackScope extends StatelessWidget {
  const ParentBackScope({
    required this.fallback,
    required this.child,
    super.key,
  });

  /// Where back goes when nothing is behind this page.
  final String fallback;
  final Widget child;

  /// The fallback of the nearest [ParentBackScope], if any.
  static String? fallbackOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_ParentBackFallback>()
      ?.fallback;

  @override
  Widget build(BuildContext context) {
    // The page's own route: right even while another page covers it.
    final first = !(ModalRoute.of(context)?.canPop ?? true);
    return _ParentBackFallback(
      fallback: fallback,
      child: PopScope(
        canPop: !first,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          GoRouter.maybeOf(context)?.go(fallback);
        },
        child: child,
      ),
    );
  }
}

class _ParentBackFallback extends InheritedWidget {
  const _ParentBackFallback({required this.fallback, required super.child});

  final String fallback;

  @override
  bool updateShouldNotify(_ParentBackFallback oldWidget) =>
      fallback != oldWidget.fallback;
}

/// The app bar's back button when the page has nothing behind it (the
/// AppBar shows none then): it goes to the [ParentBackScope]'s fallback,
/// or [defaultFallback] outside one. Null keeps the AppBar's normal back.
Widget? parentBackButton(
  BuildContext context, {
  required String defaultFallback,
}) {
  final router = GoRouter.maybeOf(context);
  if (router == null) return null;
  if (ModalRoute.of(context)?.canPop ?? true) return null;
  final fallback = ParentBackScope.fallbackOf(context) ?? defaultFallback;
  return BackButton(onPressed: () => router.go(fallback));
}
