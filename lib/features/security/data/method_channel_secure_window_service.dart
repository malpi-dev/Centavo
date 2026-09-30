import 'package:centavo/features/security/domain/secure_window_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class MethodChannelSecureWindowService implements SecureWindowService {
  MethodChannelSecureWindowService({bool? isAndroid})
    : _isAndroid = isAndroid ?? defaultTargetPlatform == TargetPlatform.android;

  static const channel = MethodChannel('com.malpidev.centavo/secure_window');

  final bool _isAndroid;

  @override
  Future<void> setSecure({required bool secure}) async {
    if (!_isAndroid) return;
    try {
      await channel.invokeMethod<void>('setSecure', {'secure': secure});
    } on MissingPluginException {
      // Not critical: the window just stays as it is.
    } on PlatformException {
      // Not critical.
    }
  }
}
