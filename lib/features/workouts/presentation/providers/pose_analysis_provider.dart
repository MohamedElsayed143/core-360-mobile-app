import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:camera/camera.dart';
import '../../../../core/firebase/firebase_client.dart';
import '../../../onboarding/presentation/providers/auth_provider.dart';
import '../../data/models/pose_analysis_model.dart';
import '../../domain/services/biomechanics_analyzer.dart';

// ─── POSE STATE ─────────────────────────────────────────────────────────────

class PoseAnalysisState {
  final String exerciseName;
  final Map<PoseLandmarkType, PoseLandmark> landmarks;
  final double currentAccuracy;
  final String currentFeedback;
  final String currentStatus; // 'GOOD', 'WARNING', 'HAZARD'
  final List<double> accuracyHistory;
  final Map<String, String> jointStress;
  final int elapsedSeconds;
  final bool isSaving;
  final bool isFinished;
  final String? savedId;

  PoseAnalysisState({
    required this.exerciseName,
    this.landmarks = const {},
    this.currentAccuracy = 0.0,
    this.currentFeedback = 'Align yourself in frame to begin.',
    this.currentStatus = 'WARNING',
    this.accuracyHistory = const [],
    this.jointStress = const {},
    this.elapsedSeconds = 0,
    this.isSaving = false,
    this.isFinished = false,
    this.savedId,
  });

  double get averageAccuracy {
    if (accuracyHistory.isEmpty) return 0.0;
    // Filter out initial calibration frames with 0 accuracy to be fair
    final actualScores = accuracyHistory.where((score) => score > 0.0).toList();
    if (actualScores.isEmpty) return 0.0;
    return actualScores.reduce((a, b) => a + b) / actualScores.length;
  }

  PoseAnalysisState copyWith({
    String? exerciseName,
    Map<PoseLandmarkType, PoseLandmark>? landmarks,
    double? currentAccuracy,
    String? currentFeedback,
    String? currentStatus,
    List<double>? accuracyHistory,
    Map<String, String>? jointStress,
    int? elapsedSeconds,
    bool? isSaving,
    bool? isFinished,
    String? savedId,
  }) {
    return PoseAnalysisState(
      exerciseName: exerciseName ?? this.exerciseName,
      landmarks: landmarks ?? this.landmarks,
      currentAccuracy: currentAccuracy ?? this.currentAccuracy,
      currentFeedback: currentFeedback ?? this.currentFeedback,
      currentStatus: currentStatus ?? this.currentStatus,
      accuracyHistory: accuracyHistory ?? this.accuracyHistory,
      jointStress: jointStress ?? this.jointStress,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      isSaving: isSaving ?? this.isSaving,
      isFinished: isFinished ?? this.isFinished,
      savedId: savedId ?? this.savedId,
    );
  }
}

// ─── POSE ANALYSIS NOTIFIER ──────────────────────────────────────────────────

class PoseAnalysisNotifier extends Notifier<PoseAnalysisState> {
  PoseDetector? _poseDetector;
  Timer? _sessionTimer;
  bool _isProcessing = false;
  int _frameCount = 0;

  @override
  PoseAnalysisState build() {
    ref.onDispose(() {
      _sessionTimer?.cancel();
      _poseDetector?.close();
    });
    return PoseAnalysisState(exerciseName: 'Squat');
  }

  /// Start a Pose Analysis tracking session
  void startSession(String exerciseName) {
    _sessionTimer?.cancel();
    _poseDetector?.close();

    // Configure pose detector stream mode
    _poseDetector = PoseDetector(
      options: PoseDetectorOptions(
        model: PoseDetectionModel.base,
        mode: PoseDetectionMode.stream,
      ),
    );

    state = PoseAnalysisState(exerciseName: exerciseName);

    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!state.isFinished && !state.isSaving) {
        state = state.copyWith(elapsedSeconds: state.elapsedSeconds + 1);
      }
    });
  }

  /// Stream frame processor
  Future<void> processCameraImage(
    CameraImage image,
    CameraDescription camera,
  ) async {
    if (_isProcessing || state.isFinished || state.isSaving) return;

    // Throttling: process every 3rd frame to ensure smooth UI layout
    _frameCount++;
    if (_frameCount % 3 != 0) return;

    _isProcessing = true;

    try {
      final inputImage = _convertCameraImage(image, camera);
      if (inputImage == null) {
        _isProcessing = false;
        return;
      }

      final detector = _poseDetector;
      if (detector == null) {
        _isProcessing = false;
        return;
      }

      final poses = await detector.processImage(inputImage);

      if (poses.isEmpty) {
        state = state.copyWith(
          landmarks: {},
          currentAccuracy: 0.0,
          currentFeedback: 'Form Analyzer calibrating... Step fully into view.',
        );
        _isProcessing = false;
        return;
      }

      final firstPose = poses.first;
      final landmarks = firstPose.landmarks;

      final normalizedExercise = state.exerciseName.toLowerCase();

      Map<String, dynamic> analysis;
      if (normalizedExercise.contains('plank')) {
        analysis = BiomechanicsAnalyzer.analyzePlank(landmarks);
      } else if (normalizedExercise.contains('press') ||
          normalizedExercise.contains('overhead') ||
          normalizedExercise.contains('shoulder')) {
        analysis = BiomechanicsAnalyzer.analyzeOverheadPress(landmarks);
      } else {
        analysis = BiomechanicsAnalyzer.analyzeSquat(landmarks);
      }

      final double score = (analysis['accuracy'] as num).toDouble();
      final String feedback = analysis['feedback'] as String;
      final String status = analysis['status'] as String;
      final Map<String, String> joints = Map<String, String>.from(
        analysis['jointStress'] ?? {},
      );

      // Accumulate score history for progress reports
      final updatedHistory = [...state.accuracyHistory, score];

      state = state.copyWith(
        landmarks: landmarks,
        currentAccuracy: score,
        currentFeedback: feedback,
        currentStatus: status,
        accuracyHistory: updatedHistory,
        jointStress: joints,
      );
    } catch (e) {
      debugPrint('Pose analysis image processing error: $e');
    } finally {
      _isProcessing = false;
    }
  }

  /// Converts CameraImage to InputImage for ML Kit compatibility
  InputImage? _convertCameraImage(CameraImage image, CameraDescription camera) {
    try {
      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      final size = Size(image.width.toDouble(), image.height.toDouble());
      final rotation = _rotationFromDescription(camera);
      final format = _formatFromImage(image);

      if (rotation == null || format == null) return null;

      final metadata = InputImageMetadata(
        size: size,
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes[0].bytesPerRow,
      );

      return InputImage.fromBytes(bytes: bytes, metadata: metadata);
    } catch (e) {
      debugPrint('Camera image conversion error: $e');
      return null;
    }
  }

  InputImageRotation? _rotationFromDescription(CameraDescription camera) {
    switch (camera.sensorOrientation) {
      case 0:
        return InputImageRotation.rotation0deg;
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      default:
        return null;
    }
  }

  InputImageFormat? _formatFromImage(CameraImage image) {
    if (image.format.group == ImageFormatGroup.yuv420) {
      return InputImageFormat.nv21;
    } else if (image.format.group == ImageFormatGroup.bgra8888) {
      return InputImageFormat.bgra8888;
    }
    return null;
  }

  /// Saves the completed Pose Analysis Result to Firestore
  Future<void> saveAnalysisSession() async {
    final auth = ref.read(authProvider);
    if (auth is! AuthenticatedWithProfile) return;

    state = state.copyWith(isSaving: true);

    try {
      _sessionTimer?.cancel();
      _poseDetector?.close();

      final firebase = ref.read(firebaseClientProvider);
      final userId = auth.user.uid;

      final docId = firebase.firestore
          .collection('users')
          .doc(userId)
          .collection('pose_analysis_results')
          .doc()
          .id;

      // Classify overall session risk level
      final avgScore = state.averageAccuracy;
      String riskLevel = 'LOW';
      if (avgScore < 55.0) {
        riskLevel = 'HIGH';
      } else if (avgScore < 75.0) {
        riskLevel = 'MEDIUM';
      }

      // Consolidate unique corrections logged during the session
      final correctionsList = <String>[];
      if (state.exerciseName.toLowerCase().contains('plank')) {
        if (avgScore < 80) {
          correctionsList.add(
            'Keep body in a straight line without sagging hips.',
          );
          correctionsList.add(
            'Tighten abdominal core and press elbows into floor.',
          );
        }
      } else {
        if (avgScore < 85) {
          correctionsList.add('Lower hips below knees for deep squat flexion.');
          correctionsList.add(
            'Keep chest upright and back straight during descent.',
          );
        }
      }
      if (correctionsList.isEmpty) {
        correctionsList.add(
          'Posture looks fantastic! Continue regular training split.',
        );
      }

      final result = PoseAnalysisResultModel(
        id: docId,
        timestamp: DateTime.now(),
        exerciseName: state.exerciseName,
        averageAccuracy: avgScore,
        riskLevel: riskLevel,
        jointStress: state.jointStress.isNotEmpty
            ? state.jointStress
            : {'core': 'GOOD', 'limbs': 'GOOD'},
        corrections: correctionsList,
        durationSeconds: state.elapsedSeconds,
      );

      // Save to user sub-collection
      await firebase.firestore
          .collection('users')
          .doc(userId)
          .collection('pose_analysis_results')
          .doc(docId)
          .set(result.toMap());

      // Save a matching Progress metric for Feature 6 progress dashboard to reference
      final progressId = firebase.progressCollection.doc().id;
      await firebase.progressCollection.doc(progressId).set({
        'id': progressId,
        'userId': userId,
        'metric': 'FORM_ACCURACY',
        'value': avgScore,
        'date': Timestamp.now(),
      });

      // Save a matching progress metric for analysis count
      final progressCountId = firebase.progressCollection.doc().id;
      await firebase.progressCollection.doc(progressCountId).set({
        'id': progressCountId,
        'userId': userId,
        'metric': 'AI_ANALYSES',
        'value': 1.0,
        'date': Timestamp.now(),
      });

      state = state.copyWith(isSaving: false, isFinished: true, savedId: docId);
    } catch (e) {
      debugPrint('Firestore pose analysis saving failed: $e');
      state = state.copyWith(isSaving: false);
    }
  }

  void reset() {
    _sessionTimer?.cancel();
    _poseDetector?.close();
    state = PoseAnalysisState(exerciseName: 'Squat');
  }
}

final poseAnalysisProvider =
    NotifierProvider<PoseAnalysisNotifier, PoseAnalysisState>(
      PoseAnalysisNotifier.new,
    );
