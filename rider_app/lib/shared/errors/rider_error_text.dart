import 'package:flutter/widgets.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../l10n/app_localizations.dart';

/// jivo_core's error message, with the rider's own wording where it differs.
/// The rider endpoints are throttled (P5 contract): a 429 reads calmly as
/// "Too many tries. Wait a moment, then try again." rather than an error.
String riderApiErrorMessage(BuildContext context, ApiError error) =>
    switch (error.code) {
      ApiErrorCode.rateLimited => AppLocalizations.of(
        context,
      ).riderTooManyTries,
      _ => apiErrorMessage(JivoCoreLocalizations.of(context), error),
    };
