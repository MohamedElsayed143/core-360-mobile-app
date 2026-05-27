import 'dart:io';
import 'package:flutter/foundation.dart';

class ApiConstants {
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:3000';
    }
    // For mobile emulators
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:3000';
    }
    // Default for iOS emulator or local network tests
    return 'http://localhost:3000';
  }

  // Endpoints
  static const String aiWorkout = '/api/ai-workout';
  static const String chat = '/api/chat';
}
