import 'package:jivo_core/jivo_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Small non-secret flags kept in shared preferences.
class AppFlags {
  AppFlags(this._prefs);

  final SharedPreferences _prefs;

  static const onboardingSeenKey = 'onboarding_seen';
  static const installedKey = 'installed';

  bool get onboardingSeen => _prefs.getBool(onboardingSeenKey) ?? false;

  Future<void> markOnboardingSeen() => _prefs.setBool(onboardingSeenKey, true);

  /// The "Have a referral code?" card at checkout was closed by [userId].
  static String referralPromptDismissedKey(int userId) =>
      'referral_prompt_dismissed_$userId';

  bool referralPromptDismissed(int userId) =>
      _prefs.getBool(referralPromptDismissedKey(userId)) ?? false;

  Future<void> dismissReferralPrompt(int userId) =>
      _prefs.setBool(referralPromptDismissedKey(userId), true);

  /// The notification permission was asked at [moment] (`signIn`,
  /// `firstOrder`) on this install; each moment asks at most once.
  static String pushPermissionAskedKey(String moment) =>
      'push_permission_asked_$moment';

  bool pushPermissionAsked(String moment) =>
      _prefs.getBool(pushPermissionAskedKey(moment)) ?? false;

  Future<void> markPushPermissionAsked(String moment) =>
      _prefs.setBool(pushPermissionAskedKey(moment), true);
}

/// Signs out a session left over from a previous install.
///
/// The iOS Keychain survives uninstalling the app, but shared preferences
/// don't: on the first run after (re)installing, stored tokens belong to an
/// old install and are cleared. Call before `SessionManager.restore()`.
Future<void> clearStaleSessionOnFreshInstall(
  SharedPreferences prefs,
  TokenStore store,
) async {
  if (prefs.getBool(AppFlags.installedKey) ?? false) return;
  try {
    await store.clear();
  } catch (_) {
    // Nothing to clear, or the store is unreadable: restore() handles it.
  }
  await prefs.setBool(AppFlags.installedKey, true);
}
