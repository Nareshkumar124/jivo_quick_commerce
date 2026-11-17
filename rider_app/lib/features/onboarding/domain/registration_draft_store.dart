import 'onboarding_forms.dart';

/// Keeps the half-filled registration form on the phone until registration
/// succeeds (UX audit RA-07): budget phones often stop the app while the
/// rider looks for their RC. Cleared on success and on sign-out. Never
/// throws.
abstract interface class RegistrationDraftStore {
  Future<RegistrationDraft?> read();
  Future<void> write(RegistrationDraft draft);
  Future<void> clear();
}

class InMemoryRegistrationDraftStore implements RegistrationDraftStore {
  RegistrationDraft? draft;

  @override
  Future<RegistrationDraft?> read() async => draft;

  @override
  Future<void> write(RegistrationDraft draft) async => this.draft = draft;

  @override
  Future<void> clear() async => draft = null;
}
