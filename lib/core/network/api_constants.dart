import 'dart:io';
import 'package:flutter/foundation.dart';

class ApiConstants {
  /// Always use the live Vercel backend.
  /// On web (debug or release) → Vercel production URL.
  /// On Android emulator (debug) → loopback alias 10.0.2.2.
  /// On everything else → Vercel production URL.
  static String get baseUrl {
    if (kIsWeb) {
      // Web always hits the live Vercel API (no localhost server exists in browser context)
      return 'https://core-360-final.vercel.app';
    }
    if (kReleaseMode) {
      return 'https://core-360-final.vercel.app';
    }
    // Native Android emulator only
    try {
      if (Platform.isAndroid) {
        return 'http://10.0.2.2:3000';
      }
    } catch (_) {}
    // iOS simulator or other platforms in debug → Vercel
    return 'https://core-360-final.vercel.app';
  }

  // Endpoints
  static const String aiWorkout = '/api/ai-workout';
  static const String chat = '/api/chat';
  static const String workouts = '/api/workouts';
}
