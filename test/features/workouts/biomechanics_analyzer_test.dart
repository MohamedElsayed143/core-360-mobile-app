import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:core_360_app/features/workouts/domain/services/biomechanics_analyzer.dart';

void main() {
  PoseLandmark landmark(PoseLandmarkType type, double x, double y, double z) {
    return PoseLandmark(type: type, x: x, y: y, z: z, likelihood: 1.0);
  }

  group('BiomechanicsAnalyzer', () {
    test('flags poor torso alignment during overhead press', () {
      final landmarks = <PoseLandmarkType, PoseLandmark>{
        PoseLandmarkType.leftShoulder: landmark(
          PoseLandmarkType.leftShoulder,
          0.4,
          0.2,
          0.0,
        ),
        PoseLandmarkType.rightShoulder: landmark(
          PoseLandmarkType.rightShoulder,
          0.6,
          0.2,
          0.0,
        ),
        PoseLandmarkType.leftHip: landmark(
          PoseLandmarkType.leftHip,
          0.75,
          0.6,
          0.0,
        ),
        PoseLandmarkType.rightHip: landmark(
          PoseLandmarkType.rightHip,
          0.85,
          0.6,
          0.0,
        ),
        PoseLandmarkType.leftElbow: landmark(
          PoseLandmarkType.leftElbow,
          0.3,
          0.4,
          0.0,
        ),
        PoseLandmarkType.rightElbow: landmark(
          PoseLandmarkType.rightElbow,
          0.7,
          0.4,
          0.0,
        ),
        PoseLandmarkType.leftWrist: landmark(
          PoseLandmarkType.leftWrist,
          0.2,
          0.6,
          0.0,
        ),
        PoseLandmarkType.rightWrist: landmark(
          PoseLandmarkType.rightWrist,
          0.8,
          0.6,
          0.0,
        ),
      };

      final result = BiomechanicsAnalyzer.analyzeOverheadPress(landmarks);

      expect(result['status'], 'HAZARD');
      expect(
        (result['feedback'] as String).toLowerCase(),
        contains('keep your back straight'),
      );
    });

    test('accepts aligned torso posture during overhead press', () {
      final landmarks = <PoseLandmarkType, PoseLandmark>{
        PoseLandmarkType.leftShoulder: landmark(
          PoseLandmarkType.leftShoulder,
          0.4,
          0.2,
          0.0,
        ),
        PoseLandmarkType.rightShoulder: landmark(
          PoseLandmarkType.rightShoulder,
          0.6,
          0.2,
          0.0,
        ),
        PoseLandmarkType.leftHip: landmark(
          PoseLandmarkType.leftHip,
          0.45,
          0.65,
          0.0,
        ),
        PoseLandmarkType.rightHip: landmark(
          PoseLandmarkType.rightHip,
          0.55,
          0.65,
          0.0,
        ),
        PoseLandmarkType.leftElbow: landmark(
          PoseLandmarkType.leftElbow,
          0.3,
          0.4,
          0.0,
        ),
        PoseLandmarkType.rightElbow: landmark(
          PoseLandmarkType.rightElbow,
          0.7,
          0.4,
          0.0,
        ),
        PoseLandmarkType.leftWrist: landmark(
          PoseLandmarkType.leftWrist,
          0.2,
          0.6,
          0.0,
        ),
        PoseLandmarkType.rightWrist: landmark(
          PoseLandmarkType.rightWrist,
          0.8,
          0.6,
          0.0,
        ),
      };

      final result = BiomechanicsAnalyzer.analyzeOverheadPress(landmarks);

      expect(result['status'], isNot('HAZARD'));
      expect(
        (result['feedback'] as String).toLowerCase(),
        contains('form correct'),
      );
    });
  });
}
