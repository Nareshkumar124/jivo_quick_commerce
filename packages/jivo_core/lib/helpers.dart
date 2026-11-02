/// App-level helpers shared by the customer and rider apps: phone-number
/// handling, the "no automatic retry" policy for Riverpod, and the
/// interfaces for opening links and reading OTPs from SMS.
///
/// This is an opt-in library: import `package:jivo_core/helpers.dart`. It is
/// not exported from `jivo_core.dart` because rider_app still declares the
/// same names locally, and a file importing both would hit ambiguous-import
/// errors. Once both apps use these, the barrel can export this library.
///
/// Only interfaces and test doubles live here. The platform implementations
/// (url_launcher, smart_auth) stay in the apps, so jivo_core gains no
/// dependencies.
///
/// Changes must be additive: never rename or remove an existing public API.
library;

export 'src/helpers/indian_mobile.dart';
export 'src/helpers/otp_autofill.dart';
export 'src/helpers/retry.dart';
export 'src/helpers/url_opener.dart';
