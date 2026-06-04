import 'dart:io';
import 'package:flutter/foundation.dart';

class ApiConstants {
  static String get baseUrl {
    // إذا كان التطبيق شغال في بيئة الـ Release (النسخة النهائية للمستخدمين)
    // أو شغال على موبايل حقيقي، يتوجه مباشرة لرابط Vercel اللايف.
    if (kReleaseMode) {
      return 'https://core-360-final.vercel.app';
    }

    // لبيئات التطوير المحلي والـ Emulators (Debug Mode)
    if (kIsWeb) {
      return 'http://localhost:3000';
    }
    
    // محاكي الأندرويد المحلي للتطوير
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:3000';
    }
    
    // الافتراضي لمحاكي iOS أو بيئات التطوير الأخرى
    return 'http://localhost:3000';
  }

  // Endpoints
  static const String aiWorkout = '/api/ai-workout';
  static const String chat = '/api/chat';
  static const String workouts = '/api/workouts';   // ✅ جلب مكتبة التمارين الحية
}