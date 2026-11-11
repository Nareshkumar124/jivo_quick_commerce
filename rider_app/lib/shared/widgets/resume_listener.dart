import 'package:flutter/widgets.dart';

/// Calls [onResume] every time the app comes back to the foreground while
/// [child] is on screen (for example a status that may have changed while
/// the rider was away; UX audit RA-06).
class ResumeListener extends StatefulWidget {
  const ResumeListener({
    required this.onResume,
    required this.child,
    super.key,
  });

  final VoidCallback onResume;
  final Widget child;

  @override
  State<ResumeListener> createState() => _ResumeListenerState();
}

class _ResumeListenerState extends State<ResumeListener> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: () => widget.onResume());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
