/// A Riverpod `retry` callback that turns off automatic retry.
///
/// Failed loads show an error state with an explicit Retry button instead
/// (`03 §4`). Pass it to `ProviderScope(retry: noAutomaticRetry)` and to
/// providers that override the scope's policy. jivo_core does not depend on
/// Riverpod; the signature matches its `Retry` typedef.
Duration? noAutomaticRetry(int retryCount, Object error) => null;
