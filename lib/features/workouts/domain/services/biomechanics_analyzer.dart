import 'dart:math' as math;
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class BiomechanicsAnalyzer {
  /// Calculate the angle between three landmarks B (vertex), A, C
  static double calculateAngle(PoseLandmark a, PoseLandmark b, PoseLandmark c) {
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

  static double calculateTorsoAlignmentAngle(
    Map<PoseLandmarkType, PoseLandmark> landmarks,
  ) {
    final leftShoulder = landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = landmarks[PoseLandmarkType.rightShoulder];
    final leftHip = landmarks[PoseLandmarkType.leftHip];
    final rightHip = landmarks[PoseLandmarkType.rightHip];

    if (leftShoulder == null ||
        rightShoulder == null ||
        leftHip == null ||
        rightHip == null) {
      return 180.0;
    }

    final shoulderMidX = (leftShoulder.x + rightShoulder.x) / 2.0;
    final shoulderMidY = (leftShoulder.y + rightShoulder.y) / 2.0;
    final hipMidX = (leftHip.x + rightHip.x) / 2.0;
    final hipMidY = (leftHip.y + rightHip.y) / 2.0;

    final double deltaX = hipMidX - shoulderMidX;
    final double deltaY = hipMidY - shoulderMidY;

    if (deltaY.abs() < 1e-6) return 90.0;

    return math.atan2(deltaX.abs(), deltaY.abs()) * (180.0 / math.pi);
  }

  /// Check if the user is pointing the camera at their face or not in an exercise pose
  static bool isFaceOnlyOrNoExercisePose(
    Map<PoseLandmarkType, PoseLandmark> landmarks,
    String exercise,
  ) {
    final nose = landmarks[PoseLandmarkType.nose];
    final leftEye = landmarks[PoseLandmarkType.leftEye];
    final rightEye = landmarks[PoseLandmarkType.rightEye];

    // Check if face landmarks are visible
    final hasFace = (nose != null && nose.likelihood > 0.7) ||
        (leftEye != null && leftEye.likelihood > 0.7) ||
        (rightEye != null && rightEye.likelihood > 0.7);

    if (!hasFace) return false; // Not even a face is detected

    // Check key body joints required for any exercise pose (hips, knees, ankles)
    final leftHip = landmarks[PoseLandmarkType.leftHip];
    final rightHip = landmarks[PoseLandmarkType.rightHip];
    final leftKnee = landmarks[PoseLandmarkType.leftKnee];
    final rightKnee = landmarks[PoseLandmarkType.rightKnee];
    final leftAnkle = landmarks[PoseLandmarkType.leftAnkle];
    final rightAnkle = landmarks[PoseLandmarkType.rightAnkle];

    final hasHips = (leftHip != null && leftHip.likelihood > 0.5) ||
        (rightHip != null && rightHip.likelihood > 0.5);
    final hasKnees = (leftKnee != null && leftKnee.likelihood > 0.5) ||
        (rightKnee != null && rightKnee.likelihood > 0.5);
    final hasAnkles = (leftAnkle != null && leftAnkle.likelihood > 0.5) ||
        (rightAnkle != null && rightAnkle.likelihood > 0.5);

    // If we have a face, but lack hips, knees, or ankles, we are showing face-only or close-up
    return !hasHips || !hasKnees || !hasAnkles;
  }

  /// Classify exercise from landmark coordinates automatically
  static String classifyExercise(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final leftShoulder = landmarks[PoseLandmarkType.leftShoulder];
    final leftHip = landmarks[PoseLandmarkType.leftHip];
    final leftKnee = landmarks[PoseLandmarkType.leftKnee];
    final leftElbow = landmarks[PoseLandmarkType.leftElbow];
    final leftWrist = landmarks[PoseLandmarkType.leftWrist];

    if (leftShoulder == null || leftHip == null) return 'Squat';

    // Calculate torso slope to see if they are horizontal
    final double dx = (leftHip.x - leftShoulder.x).abs();
    final double dy = (leftHip.y - leftShoulder.y).abs();
    final isHorizontal = dx > dy * 0.7; // significant horizontal displacement

    if (isHorizontal) {
      if (leftElbow != null && leftWrist != null) {
        final elbowAngle = calculateAngle(leftShoulder, leftElbow, leftWrist);
        if (elbowAngle < 130) {
          return 'Push-Up';
        }
      }
      return 'Plank';
    } else {
      // Check for Overhead Press: wrists higher than shoulders
      if (leftWrist != null && leftWrist.y < leftShoulder.y) {
        return 'Overhead Press';
      }

      // Check for Bicep Curl: Elbow bent (< 130) and wrist below shoulder but above hip
      if (leftElbow != null && leftWrist != null) {
        final elbowAngle = calculateAngle(leftShoulder, leftElbow, leftWrist);
        if (elbowAngle < 130 && leftWrist.y > leftShoulder.y && leftWrist.y < leftHip.y) {
          return 'Bicep Curl';
        }
      }

      // Check for Squat: Knee angle bent (< 140)
      if (leftKnee != null && landmarks[PoseLandmarkType.leftAnkle] != null) {
        final kneeAngle = calculateAngle(leftHip, leftKnee, landmarks[PoseLandmarkType.leftAnkle]!);
        if (kneeAngle < 140) {
          return 'Squat';
        }
      }

      return 'Squat'; // Default fallback
    }
  }

  /// Unified entrypoint for analyzing any exercise
  static Map<String, dynamic> analyzeAnyExercise(
    Map<PoseLandmarkType, PoseLandmark> landmarks,
    String exerciseName,
  ) {
    String detectedName = exerciseName;
    if (exerciseName == 'Auto-Detect') {
      detectedName = classifyExercise(landmarks);
    }

    final normalized = detectedName.toLowerCase();
    Map<String, dynamic> analysis;

    if (normalized.contains('plank')) {
      analysis = analyzePlank(landmarks);
    } else if (normalized.contains('push-up') || normalized.contains('push up')) {
      analysis = analyzePushUp(landmarks);
    } else if (normalized.contains('press') ||
        normalized.contains('overhead') ||
        normalized.contains('shoulder')) {
      analysis = analyzeOverheadPress(landmarks);
    } else if (normalized.contains('curl') || normalized.contains('bicep')) {
      analysis = analyzeBicepCurl(landmarks);
    } else if (normalized.contains('squat')) {
      analysis = analyzeSquat(landmarks);
    } else {
      analysis = analyzeGeneralExercise(landmarks, detectedName);
    }

    analysis['detectedExercise'] = detectedName;
    return analysis;
  }

  /// Analyze Squat biomechanics using skeletal landmarks
  static Map<String, dynamic> analyzeSquat(
    Map<PoseLandmarkType, PoseLandmark> landmarks,
  ) {
    final leftHip = landmarks[PoseLandmarkType.leftHip];
    final leftKnee = landmarks[PoseLandmarkType.leftKnee];
    final leftAnkle = landmarks[PoseLandmarkType.leftAnkle];
    final leftShoulder = landmarks[PoseLandmarkType.leftShoulder];

    if (leftHip == null ||
        leftKnee == null ||
        leftAnkle == null ||
        leftShoulder == null) {
      return {
        'accuracy': 0.0,
        'feedback':
            'CALIBRATING: Stand sideways and ensure shoulders, hips, knees, and ankles are in frame.',
        'right': 'Looking for posture...',
        'wrong': 'Step fully into camera frame.',
        'status': 'WARNING',
        'jointStress': {'knees': 'CALIBRATING', 'back': 'CALIBRATING'},
      };
    }

    // 1. Calculate Knee Flexion Angle (Hip-Knee-Ankle)
    final kneeAngle = calculateAngle(leftHip, leftKnee, leftAnkle);

    // 2. Calculate Torso Alignment/Back angle (Shoulder-Hip-Knee)
    final backAngle = calculateAngle(leftShoulder, leftHip, leftKnee);
    final torsoLeanAngle = calculateTorsoAlignmentAngle(landmarks);

    double accuracy = 100.0;
    String feedback = 'Form looks good! Maintain rhythm.';
    String status = 'GOOD';
    String kneeStatus = 'GOOD';
    String backStatus = 'GOOD';
    String right = 'Torso aligned over hips.';
    String wrong = '';

    // Rule: Back straightness (Shoulder-Hip-Knee). Under 135 deg is severe leaning forward.
    if (backAngle < 135.0 || torsoLeanAngle > 20.0) {
      accuracy -= 35.0;
      feedback =
          'Alert: Keep your back straight! Stack your torso over your hips.';
      backStatus = 'CRITICAL';
      status = 'HAZARD';
      wrong = 'Arching or rounding back excessively.';
    } else if (backAngle < 150.0 || torsoLeanAngle > 12.0) {
      accuracy -= 15.0;
      feedback = 'Warning: Arching back. Keep chest up and back straight.';
      backStatus = 'WARNING';
      wrong = 'Slight spine curvature detected.';
      if (status == 'GOOD') status = 'WARNING';
    }

    // Rule: Squat Depth (Knee Angle).
    if (kneeAngle > 140.0) {
      kneeStatus = 'GOOD';
      feedback = 'Ready! Drop hips down and push knees out.';
      right = 'Knees aligned, body in starting stance.';
    } else if (kneeAngle > 115.0) {
      accuracy -= 20.0;
      kneeStatus = 'WARNING';
      feedback =
          'Squat depth is shallow! Sit deeper, lower your hips past knees.';
      wrong = '${wrong.isNotEmpty ? '$wrong ' : ''}Squat depth is shallow.';
      if (status == 'GOOD') status = 'WARNING';
    } else {
      kneeStatus = 'GOOD';
      right = '${right.isNotEmpty ? '$right ' : ''}Excellent squat depth!';
      if (status == 'GOOD') feedback = 'Excellent squat depth! Keep pushing.';
    }

    if (wrong.isEmpty) {
      wrong = 'No form errors detected.';
    }

    accuracy = accuracy.clamp(0.0, 100.0);

    return {
      'accuracy': accuracy,
      'feedback': feedback,
      'right': right,
      'wrong': wrong,
      'status': status,
      'jointStress': {'knees': kneeStatus, 'back': backStatus},
    };
  }

  /// Analyze Push-Up biomechanics using skeletal landmarks
  static Map<String, dynamic> analyzePushUp(
    Map<PoseLandmarkType, PoseLandmark> landmarks,
  ) {
    final leftShoulder = landmarks[PoseLandmarkType.leftShoulder];
    final leftHip = landmarks[PoseLandmarkType.leftHip];
    final leftKnee = landmarks[PoseLandmarkType.leftKnee];
    final leftElbow = landmarks[PoseLandmarkType.leftElbow];
    final leftWrist = landmarks[PoseLandmarkType.leftWrist];

    if (leftShoulder == null || leftHip == null || leftKnee == null || leftElbow == null || leftWrist == null) {
      return {
        'accuracy': 0.0,
        'feedback': 'CALIBRATING: Align full body horizontally in frame.',
        'right': 'Looking for posture...',
        'wrong': 'Step fully into camera frame.',
        'status': 'WARNING',
        'jointStress': {'elbows': 'CALIBRATING', 'core': 'CALIBRATING'},
      };
    }

    final bodyAngle = calculateAngle(leftShoulder, leftHip, leftKnee);
    final elbowAngle = calculateAngle(leftShoulder, leftElbow, leftWrist);

    double accuracy = 100.0;
    String status = 'GOOD';
    String elbowStatus = 'GOOD';
    String coreStatus = 'GOOD';
    String right = 'Core is locked and aligned.';
    String wrong = '';

    if (bodyAngle < 155.0) {
      accuracy -= 30.0;
      coreStatus = 'CRITICAL';
      status = 'HAZARD';
      wrong = 'Hips are sagging or elevated too high. Flatten your body.';
    } else if (bodyAngle < 168.0) {
      accuracy -= 15.0;
      coreStatus = 'WARNING';
      status = 'WARNING';
      wrong = 'Keep body straight. Engage your core.';
    }

    if (elbowAngle > 140.0) {
      right = 'Arms fully extended at peak.';
    } else if (elbowAngle > 100.0) {
      accuracy -= 15.0;
      elbowStatus = 'WARNING';
      if (status == 'GOOD') status = 'WARNING';
      wrong = '${wrong.isNotEmpty ? '$wrong ' : ''}Push-up depth is too shallow.';
    } else {
      right = '${right.isNotEmpty ? '$right ' : ''}Excellent depth! Great chest press.';
    }

    if (wrong.isEmpty) {
      wrong = 'No form errors detected.';
    }

    accuracy = accuracy.clamp(0.0, 100.0);

    return {
      'accuracy': accuracy,
      'feedback': wrong == 'No form errors detected.' ? 'Excellent push-up form!' : wrong,
      'right': right,
      'wrong': wrong,
      'status': status,
      'jointStress': {'elbows': elbowStatus, 'core': coreStatus},
    };
  }

  /// Analyze Bicep Curl biomechanics using skeletal landmarks
  static Map<String, dynamic> analyzeBicepCurl(
    Map<PoseLandmarkType, PoseLandmark> landmarks,
  ) {
    final leftShoulder = landmarks[PoseLandmarkType.leftShoulder];
    final leftElbow = landmarks[PoseLandmarkType.leftElbow];
    final leftWrist = landmarks[PoseLandmarkType.leftWrist];
    final leftHip = landmarks[PoseLandmarkType.leftHip];

    if (leftShoulder == null || leftElbow == null || leftWrist == null || leftHip == null) {
      return {
        'accuracy': 0.0,
        'feedback': 'CALIBRATING: Stand sideways with your arm fully visible.',
        'right': 'Looking for posture...',
        'wrong': 'Step fully into camera frame.',
        'status': 'WARNING',
        'jointStress': {'elbows': 'CALIBRATING', 'shoulders': 'CALIBRATING'},
      };
    }

    final elbowAngle = calculateAngle(leftShoulder, leftElbow, leftWrist);
    final torsoLeanAngle = calculateTorsoAlignmentAngle(landmarks);

    double accuracy = 100.0;
    String status = 'GOOD';
    String elbowStatus = 'GOOD';
    String shoulderStatus = 'GOOD';
    String right = 'Elbows pinned to your sides.';
    String wrong = '';

    if (torsoLeanAngle > 15.0) {
      accuracy -= 30.0;
      shoulderStatus = 'WARNING';
      status = 'HAZARD';
      wrong = 'Stop swinging your torso! Keep your upper body static.';
    }

    if (elbowAngle < 60.0) {
      right = '${right.isNotEmpty ? '$right ' : ''}Great full squeeze at the peak.';
    } else if (elbowAngle > 150.0) {
      right = '${right.isNotEmpty ? '$right ' : ''}Great full extension at the bottom.';
    }

    if (wrong.isEmpty) {
      wrong = 'No form errors detected.';
    }

    accuracy = accuracy.clamp(0.0, 100.0);

    return {
      'accuracy': accuracy,
      'feedback': wrong == 'No form errors detected.' ? 'Great curl control!' : wrong,
      'right': right,
      'wrong': wrong,
      'status': status,
      'jointStress': {'elbows': elbowStatus, 'shoulders': shoulderStatus},
    };
  }

  /// Analyze Overhead Press biomechanics using skeletal landmarks
  static Map<String, dynamic> analyzeOverheadPress(
    Map<PoseLandmarkType, PoseLandmark> landmarks,
  ) {
    final leftShoulder = landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = landmarks[PoseLandmarkType.rightShoulder];
    final leftHip = landmarks[PoseLandmarkType.leftHip];
    final rightHip = landmarks[PoseLandmarkType.rightHip];
    final leftElbow = landmarks[PoseLandmarkType.leftElbow];
    final rightElbow = landmarks[PoseLandmarkType.rightElbow];

    if (leftShoulder == null ||
        rightShoulder == null ||
        leftHip == null ||
        rightHip == null ||
        leftElbow == null ||
        rightElbow == null) {
      return {
        'accuracy': 0.0,
        'feedback':
            'CALIBRATING: Align shoulders, hips, and elbows in frame for the press.',
        'right': 'Looking for posture...',
        'wrong': 'Step fully into camera frame.',
        'status': 'WARNING',
        'jointStress': {'torso': 'CALIBRATING', 'shoulders': 'CALIBRATING'},
      };
    }

    final torsoLeanAngle = calculateTorsoAlignmentAngle(landmarks);

    double accuracy = 100.0;
    String feedback = 'Form correct! Keep your ribs stacked over your hips.';
    String status = 'GOOD';
    String torsoStatus = 'GOOD';
    String shoulderStatus = 'GOOD';
    String right = 'Ribs stacked over hips.';
    String wrong = '';

    if (torsoLeanAngle > 20.0) {
      accuracy -= 35.0;
      feedback =
          'Alert: Keep your back straight! Your torso is leaning too far.';
      torsoStatus = 'CRITICAL';
      shoulderStatus = 'WARNING';
      status = 'HAZARD';
      wrong = 'Torso is leaning excessively backward.';
    } else if (torsoLeanAngle > 12.0) {
      accuracy -= 18.0;
      feedback =
          'Warning: Slight torso drift. Keep your ribs stacked and back straight.';
      torsoStatus = 'WARNING';
      wrong = 'Slight torso lean detected.';
      if (status == 'GOOD') status = 'WARNING';
    }

    if (wrong.isEmpty) {
      wrong = 'No form errors detected.';
      right = 'Arms pushing vertically, hips stable.';
    }

    accuracy = accuracy.clamp(0.0, 100.0);

    return {
      'accuracy': accuracy,
      'feedback': feedback,
      'right': right,
      'wrong': wrong,
      'status': status,
      'jointStress': {'torso': torsoStatus, 'shoulders': shoulderStatus},
    };
  }

  /// Analyze Plank alignment using skeletal landmarks
  static Map<String, dynamic> analyzePlank(
    Map<PoseLandmarkType, PoseLandmark> landmarks,
  ) {
    final leftShoulder = landmarks[PoseLandmarkType.leftShoulder];
    final leftHip = landmarks[PoseLandmarkType.leftHip];
    final leftKnee = landmarks[PoseLandmarkType.leftKnee];

    if (leftShoulder == null || leftHip == null || leftKnee == null) {
      return {
        'accuracy': 0.0,
        'feedback': 'CALIBRATING: Align your full body horizontally in frame.',
        'right': 'Looking for posture...',
        'wrong': 'Step fully into camera frame.',
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
    String right = 'Neutral spine alignment.';
    String wrong = '';

    // In a plank, the angle should be straight (165 - 180 deg)
    if (bodyAngle < 155.0) {
      accuracy -= 40.0;
      hipStatus = 'CRITICAL';
      coreStatus = 'CRITICAL';
      status = 'HAZARD';
      feedback =
          'Danger: Sagging or high hips detected! Engage your core and flatten your body.';
      wrong = 'Sagging or elevated hips (improper alignment).';
    } else if (bodyAngle < 168.0) {
      accuracy -= 20.0;
      hipStatus = 'WARNING';
      coreStatus = 'WARNING';
      status = 'WARNING';
      feedback =
          'Warning: Hip alignment is uneven. Keep body in a straight line.';
      wrong = 'Hip alignment is slightly uneven.';
    }

    if (wrong.isEmpty) {
      wrong = 'No form errors detected.';
      right = 'Neutral spine, shoulders stacked, hips aligned.';
    }

    accuracy = accuracy.clamp(0.0, 100.0);

    return {
      'accuracy': accuracy,
      'feedback': feedback,
      'right': right,
      'wrong': wrong,
      'status': status,
      'jointStress': {'hips': hipStatus, 'core': coreStatus},
    };
  }

  /// General fallback analyzer for any custom exercise
  static Map<String, dynamic> analyzeGeneralExercise(
    Map<PoseLandmarkType, PoseLandmark> landmarks,
    String exerciseName,
  ) {
    final leftShoulder = landmarks[PoseLandmarkType.leftShoulder];
    final leftHip = landmarks[PoseLandmarkType.leftHip];

    if (leftShoulder == null || leftHip == null) {
      return {
        'accuracy': 0.0,
        'feedback': 'CALIBRATING: Ensure your body is in the camera frame.',
        'right': 'Aligning posture...',
        'wrong': 'Step fully in frame.',
        'status': 'WARNING',
        'jointStress': {'torso': 'CALIBRATING'},
      };
    }

    final torsoLeanAngle = calculateTorsoAlignmentAngle(landmarks);
    double accuracy = 100.0;
    String status = 'GOOD';
    String torsoStatus = 'GOOD';
    String right = 'Good posture stability.';
    String wrong = '';

    if (torsoLeanAngle > 25.0) {
      accuracy -= 25.0;
      torsoStatus = 'WARNING';
      status = 'WARNING';
      wrong = 'Ensure your back is straight. Leaning too far.';
    }

    if (wrong.isEmpty) {
      wrong = 'No form errors detected.';
      right = 'Torso is aligned. Joint loads are balanced.';
    }

    accuracy = accuracy.clamp(0.0, 100.0);

    return {
      'accuracy': accuracy,
      'feedback': 'Analyzing $exerciseName form...',
      'right': right,
      'wrong': wrong,
      'status': status,
      'jointStress': {'torso': torsoStatus},
    };
  }
}
