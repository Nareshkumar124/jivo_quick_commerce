import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// The "No internet" strip under the app bar (task-step shell §3, home spec
/// §8): COD colours, a `wifi_off` icon and [message], in a live region so
/// TalkBack reads it when it appears. Shared by the task screens and home
/// (UX audit RA-10).
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = RiderColors.of(context);
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.codBg,
          border: Border(
            bottom: BorderSide(
              color: colors.codBorder,
              width: RiderColors.borderWidth,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.wifi_off, color: colors.codText),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(fontSize: 16, color: colors.codText),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
