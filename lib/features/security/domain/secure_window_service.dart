/// Android FLAG_SECURE: hides the app content in the recents screen and blocks
/// screenshots.
// ignore: one_member_abstracts, port implemented by the platform adapter
abstract interface class SecureWindowService {
  Future<void> setSecure({required bool secure});
}
