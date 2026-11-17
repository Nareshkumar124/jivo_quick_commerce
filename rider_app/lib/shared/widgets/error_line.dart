import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// An inline error: the `error` icon and the message in
/// `rider.color.danger` (6.46:1 on white), 16 sp / 600, inside a live
/// region so TalkBack reads it out when it appears (UX audits RA-03 and
/// RA-18). The same style as [PrimaryActionBar]'s error line, for errors
/// shown under a field or in a list.
class ErrorLine extends StatelessWidget {
  const ErrorLine(this.message, {this.textKey, super.key});

  final String message;

  /// Key on the [Text], so tests can find the message.
  final Key? textKey;

  @override
  Widget build(BuildContext context) {
    final danger = RiderColors.of(context).danger;
    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error, color: danger),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              key: textKey,
              style: TextStyle(
                color: danger,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
