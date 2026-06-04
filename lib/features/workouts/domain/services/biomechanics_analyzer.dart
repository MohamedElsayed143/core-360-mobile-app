import 'dart:math' as math;
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class BiomechanicsAnalyzer {
  /// Calculate the angle between three landmarks B (vertex), A, C
  static double calculateAngle(
    PoseLandmark a,
    PoseLandmark b,
    PoseLandmark c,
  ) {
    // Vector AB
    final double abX = a.x - b.x;
    final double abY = a.y - b.y;
    final double abZ = a.z - b.z;

    // Vector CB
    final double cbX = c.x - b.x;
    final double cbY = c.y - b.y;
    final double cbZ = c.z - b.z;

    // Dot product AB . CB
    final double dotProduct = (abX * cbX) + (abY * cbY) + (abZ * cbZ);

    // Magnitudes
    final double magAB = math.sqrt((abX * abX) + (abY * abY) + (abZ * abZ));
    final double magCB = math.sqrt((cbX * cbX) + (cbY * cbY) + (cbZ * cbZ));

    if (magAB == 0 || magCB == 0) return 180.0;

    // Cosine of the angle
    final double cosAngle = dotProduct / (magAB * magCB);
    final double clippedCos = cosAngle.clamp(-1.0, 1.0);

    // Angle in radians and convert to degrees
    final double rad = math.acos(clippedCos);
    return rad * (180.0 / math.pi);
  }

  /// Analyze Squat biomechanics using skeletal landmarks
  /// Returns a Map containing:
  /// - 'accuracy': double (0 to 100)
  /// - 'feedback': String
  /// - 'status': String ('GOOD', 'WARNING', 'HAZARD')
  /// - 'jointStress': `Map<String, String>` (individual joint status)
  static Map<String, dynamic> analyzeSquat(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final leftHip = landmarks[PoseLandmarkType.leftHip];
    final leftKnee = landmarks[PoseLandmarkType.leftKnee];
    final leftAnkle = landmarks[PoseLandmarkType.leftAnkle];
    final leftShoulder = landmarks[PoseLandmarkType.leftShoulder];

    if (leftHip == null || leftKnee == null || leftAnkle == null || leftShoulder == null) {
      return {
        'accuracy': 0.0,
        'feedback': 'CALIBRATING: Stand sideways and ensure shoulders, hips, knees, and ankles are in frame.',
        'status': 'WARNING',
        'jointStress': {'knees': 'CALIBRATING', 'back': 'CALIBRATING'},
      };
    }

    // 1. Calculate Knee Flexion Angle (Hip-Knee-Ankle)
    final kneeAngle = calculateAngle(leftHip, leftKnee, leftAnkle);

    // 2. Calculate Torso Alignment/Back angle (Shoulder-Hip-Knee)
    final backAngle = calculateAngle(leftShoulder, leftHip, leftKnee);

    double accuracy = 100.0;
    String feedback = 'Form looks good! Maintain rhythm.';
    String status = 'GOOD';
    String kneeStatus = 'GOOD';
    String backStatus = 'GOOD';

    // Rule: Back straightness (Shoulder-Hip-Knee). Under 135 deg is severe leaning forward.
    if (backAngle < 135.0) {
      accuracy -= 35.0;
      feedback = 'Alert: Leaning too far forward! Keep your chest upright.';
      backStatus = 'CRITICAL';
      status = 'HAZARD';
    } else if (backAngle < 150.0) {
      accuracy -= 15.0;
      feedback = 'Warning: Arching back. Keep chest up and back straight.';
      backStatus = 'WARNING';
      if (status == 'GOOD') status = 'WARNING';
    }

    // Rule: Squat Depth (Knee Angle).
    // Ideal deep squat knee flexion is <= 100 degrees.
    // Standing is ~170-180 degrees.
    // If the knee is flexed (squatting phase < 150 deg):
    if (kneeAngle > 140.0) {
      // standing/calibrating phase
      kneeStatus = 'GOOD';
      feedback = 'Ready! Drop hips down and push knees out.';
    } else if (kneeAngle > 115.0) {
      // shallow squat
      accuracy -= 20.0;
      kneeStatus = 'WARNING';
      feedback = 'Squat depth is shallow! Sit deeper, lower your hips past knees.';
      if (status == 'GOOD') status = 'WARNING';
    } else {
      // great depth
      kneeStatus = 'GOOD';
      if (status == 'GOOD') feedback = 'Excellent squat depth! Keep pushing.';
    }

    accuracy = accuracy.clamp(0.0, 100.0);

    return {
      'accuracy': accuracy,
      'feedback': feedback,
      'status': status,
      'jointStress': {
        'knees': kneeStatus,
        'back': backStatus,
      },
    };
  }

  /// Analyze Plank alignment using skeletal landmarks
  static Map<String, dynamic> analyzePlank(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final leftShoulder = landmarks[PoseLandmarkType.leftShoulder];
    final leftHip = landmarks[PoseLandmarkType.leftHip];
    final leftKnee = landmarks[PoseLandmarkType.leftKnee];

    if (leftShoulder == null || leftHip == null || leftKnee == null) {
      return {
        'accuracy': 0.0,
        'feedback': 'CALIBRATING: Align your full body horizontally in frame.',
        'status': 'WARNING',
        'jointStress': {'hips': 'CALIBRATING', 'core': 'CALIBRATING'},
      };
    }

    // Calculate core alignment angle (Shoulder-Hip-Knee). Should be close to 180 degrees (straight line).
    final bodyAngle = calculateAngle(leftShoulder, leftHip, leftKnee);

    double accuracy = 100.0;
    String feedback = 'Core is locked and aligned! Form looks perfect.';
    String status = 'GOOD';
    String hipStatus = 'GOOD';
    String coreStatus = 'GOOD';

    // In a plank, the angle should be straight (165 - 180 deg)
    if (bodyAngle < 155.0) {
      accuracy -= 40.0;
      hipStatus = 'CRITICAL';
      coreStatus = 'CRITICAL';
      status = 'HAZARD';
      feedback = 'Danger: Sagging or high hips detected! Engage your core and flatten your body.';
    } else if (bodyAngle < 168.0) {
      accuracy -= 20.0;
      hipStatus = 'WARNING';
      coreStatus = 'WARNING';
      status = 'WARNING';
      feedback = 'Warning: Hip alignment is uneven. Keep body in a straight line.';
    }

    accuracy = accuracy.clamp(0.0, 100.0);

    return {
      'accuracy': accuracy,
      'feedback': feedback,
      'status': status,
      'jointStress': {
        'hips': hipStatus,
        'core': coreStatus,
      },
    };
  }
}
