import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Service to handle Device Fingerprinting and Threat Detection (Requirement 49).
class IntegrityService {

  /// Initializes Firebase App Check for threat detection.
  static Future<void> initialize() async {
    try {
      await Firebase.initializeApp();
      await FirebaseAppCheck.instance.activate(
        androidProvider: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
        appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.deviceCheck,
      );
    } catch (e) {
      debugPrint('App Check initialization failed: $e');
    }
  }

  /// Fetches the App Check token to include in API requests for server-side validation.
  static Future<String?> getAppCheckToken() async {
    try {
      return await FirebaseAppCheck.instance.getToken();
    } catch (e) {
      debugPrint('Failed to get App Check token: $e');
      return null;
    }
  }
}
