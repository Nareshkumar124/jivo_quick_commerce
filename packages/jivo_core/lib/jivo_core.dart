/// Shared core for the Jivo mobile apps (customer and rider).
///
/// Theme tokens, env/flavor config, the Dio client factory with the
/// client-info interceptor, the session (token storage, auth/refresh
/// interceptor), app-control signals (force update, maintenance), the API
/// error model and its user-facing messages, the analytics wrapper and the
/// Sentry init helper.
///
/// Changes must be additive: never rename or remove an existing public API.
library;

export 'src/analytics/analytics.dart';
export 'src/app_control/app_control.dart';
export 'src/env/app_env.dart';
export 'src/errors/api_error.dart';
export 'src/errors/api_error_messages.dart';
export 'src/l10n/generated/jivo_core_localizations.dart';
export 'src/monitoring/sentry.dart';
export 'src/network/client_info.dart';
export 'src/network/interceptors.dart';
export 'src/network/jivo_dio.dart';
export 'src/session/auth_interceptor.dart';
export 'src/session/session_manager.dart';
export 'src/session/token_refresher.dart';
export 'src/session/token_store.dart';
export 'src/theme/jivo_theme.dart';
export 'src/util/app_version.dart';
export 'src/util/money_format.dart';
