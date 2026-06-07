import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/pose_analysis_provider.dart';
import 'pose_report_screen.dart';

class PoseAnalysisScreen extends ConsumerStatefulWidget {
  const PoseAnalysisScreen({super.key});

  @override
  ConsumerState<PoseAnalysisScreen> createState() => _PoseAnalysisScreenState();
}

class _PoseAnalysisScreenState extends ConsumerState<PoseAnalysisScreen> {
  List<CameraDescription> _cameras = [];
  CameraController? _cameraController;
  int _selectedCameraIndex = 0;
  bool _isCameraReady = false;
  String _selectedExercise = 'Squat';
  bool _showCalibrator = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initCameras();
    });
  }

  Future<void> _initCameras() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        _showError('No cameras found on device.');
        return;
      }
      
      // Select the rear camera by default, or front if rear is unavailable
      final rearCameraIndex = _cameras.indexWhere((c) => c.lensDirection == CameraLensDirection.back);
      _selectedCameraIndex = rearCameraIndex != -1 ? rearCameraIndex : 0;

      await _startCamera();
    } catch (e) {
      _showError('Failed to initialize cameras: $e');
    }
  }

  Future<void> _startCamera() async {
    if (_cameras.isEmpty) return;
    
    setState(() => _isCameraReady = false);
    _cameraController?.dispose();

    final camera = _cameras[_selectedCameraIndex];
    _cameraController = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    try {
      await _cameraController!.initialize();
      setState(() => _isCameraReady = true);

      // Start the frame stream to feed the provider
      _cameraController!.startImageStream((image) {
        if (mounted && _cameraController != null) {
          ref.read(poseAnalysisProvider.notifier).processCameraImage(image, camera);
        }
      });
    } catch (e) {
      _showError('Camera preview mounting failed: $e');
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message, style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  void _toggleCamera() {
    if (_cameras.length < 2) return;
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    _startCamera();
  }

  void _triggerStart() {
    setState(() => _showCalibrator = false);
    ref.read(poseAnalysisProvider.notifier).startSession(_selectedExercise);
  }

  void _triggerFinish() async {
    final notifier = ref.read(poseAnalysisProvider.notifier);
    await notifier.saveAnalysisSession();
    
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const PoseReportScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final poseState = ref.watch(poseAnalysisProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ─── CAMERA FEED VIEWPORT ─────────────────────────────────────────
          if (_isCameraReady && _cameraController != null)
            Center(
              child: AspectRatio(
                aspectRatio: _cameraController!.value.aspectRatio,
                child: CameraPreview(_cameraController!),
              ),
            )
          else
            const Center(
              child: CircularProgressIndicator(color: AppTheme.cyberCyan),
            ),

          // ─── SKELETAL OVERLAY CANVAS ──────────────────────────────────────
          if (_isCameraReady &&
              _cameraController != null &&
              poseState.landmarks.isNotEmpty &&
              !_showCalibrator)
            IgnorePointer(
              child: AspectRatio(
                aspectRatio: _cameraController!.value.aspectRatio,
                child: CustomPaint(
                  painter: PosePainter(
                    poseState.landmarks,
                    Size(
                      _cameraController!.value.previewSize!.height,
                      _cameraController!.value.previewSize!.width,
                    ),
                    InputImageRotation.rotation90deg, // default stream preset rotation
                    _cameras[_selectedCameraIndex].lensDirection == CameraLensDirection.front,
                  ),
                ),
              ),
            ),

          // ─── HUD WARNING STRIP (GLOWING OVERLAY) ────────────────────────
          if (!_showCalibrator) _buildWarningHudStrip(poseState),

          // ─── TOP CONTROL PILL ──────────────────────────────────────────
          Positioned(
            top: 54,
            left: 20,
            right: 20,
            child: _buildTopControlPill(poseState),
          ),

          // ─── CALIBRATION/SELECTION SURVEY VIEW ───────────────────────────
          if (_showCalibrator)
            _buildCalibrationOverlay()
          else
            // ─── BOTTOM CONTROLS ACTIONS ────────────────────────────────────
            Positioned(
              bottom: 40,
              left: 30,
              right: 30,
              child: _buildBottomActionBar(poseState),
            ),
        ],
      ),
    );
  }

  Widget _buildWarningHudStrip(PoseAnalysisState state) {
    Color glowColor = AppTheme.cyberCyan;
    Color darkColor = AppTheme.cyberCyan.withValues(alpha: 0.08);
    IconData icon = Icons.check_circle_outline;

    if (state.currentStatus == 'HAZARD') {
      glowColor = Colors.redAccent;
      darkColor = Colors.redAccent.withValues(alpha: 0.12);
      icon = Icons.warning_amber_rounded;
    } else if (state.currentStatus == 'WARNING') {
      glowColor = AppTheme.warningAmber;
      darkColor = AppTheme.warningAmber.withValues(alpha: 0.1);
      icon = Icons.error_outline;
    }

    return Positioned(
      top: 120,
      left: 20,
      right: 20,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.darkSurface.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: glowColor.withValues(alpha: 0.4), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: glowColor.withValues(alpha: 0.08),
              blurRadius: 20,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: darkColor,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: glowColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'POSE ACCURACY',
                        style: GoogleFonts.outfit(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textMuted,
                          letterSpacing: 1.0,
                        ),
                      ),
                      Text(
                        '${state.currentAccuracy.toStringAsFixed(0)}%',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: glowColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    state.currentFeedback.toUpperCase(),
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.95),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopControlPill(PoseAnalysisState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorderColor, width: 1.0),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: AppTheme.textSub, size: 16),
                onPressed: () {
                  ref.read(poseAnalysisProvider.notifier).reset();
                  Navigator.pop(context);
                },
              ),
              const SizedBox(width: 4),
              Text(
                'NEURAL FORM ENGINE',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          if (!_showCalibrator)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatTime(state.elapsedSeconds),
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.redAccent,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            )
          else if (_cameras.length > 1)
            IconButton(
              icon: const Icon(Icons.flip_camera_ios_outlined, color: AppTheme.textSub, size: 20),
              onPressed: _toggleCamera,
            ),
        ],
      ),
    );
  }

  Widget _buildCalibrationOverlay() {
    return Stack(
      children: [
        // Dark translucent filter
        Positioned.fill(
          child: Container(color: Colors.black.withValues(alpha: 0.55)),
        ),

        // Calibration Frame Box Illustration
        Center(
          child: Container(
            width: 260,
            height: 380,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: AppTheme.cyberCyan.withValues(alpha: 0.4), width: 2.0),
            ),
            child: Stack(
              children: [
                // Glowing calibration corners
                _buildCornerGlow(0, 0),
                _buildCornerGlow(null, 0),
                _buildCornerGlow(0, null),
                _buildCornerGlow(null, null),

                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.accessibility_new_outlined,
                          color: AppTheme.cyberCyan.withValues(alpha: 0.8),
                          size: 48,
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'STAND IN POSITION',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Place your device standing vertically. Step back until your whole body fits inside this frame.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            color: AppTheme.textMuted,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Settings Selector Pill at Bottom
        Positioned(
          bottom: 40,
          left: 30,
          right: 30,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: AppTheme.darkSurface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppTheme.cardBorderColor, width: 1.2),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'CHOOSE EXERCISE',
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textMuted,
                        letterSpacing: 1.0,
                      ),
                    ),
                    Row(
                      children: [
                        _buildExerciseSelectionBtn('Squat'),
                        const SizedBox(width: 8),
                        _buildExerciseSelectionBtn('Plank'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _triggerStart,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Container(
                    height: 52,
                    alignment: Alignment.center,
                    child: Text(
                      'START NEURAL CAMERA',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        fontSize: 13,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCornerGlow(double? left, double? top) {
    return Positioned(
      left: left,
      top: top,
      right: left == null ? 0 : null,
      bottom: top == null ? 0 : null,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: AppTheme.cyberCyan,
          borderRadius: BorderRadius.circular(6),
          boxShadow: [
            BoxShadow(
              color: AppTheme.cyberCyan.withValues(alpha: 0.6),
              blurRadius: 10,
              spreadRadius: 2,
            )
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseSelectionBtn(String name) {
    final isSelected = _selectedExercise == name;
    return GestureDetector(
      onTap: () => setState(() => _selectedExercise = name),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.cyberCyan.withValues(alpha: 0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.cyberCyan.withValues(alpha: 0.5) : AppTheme.textMuted,
            width: 1.2,
          ),
        ),
        child: Text(
          name.toUpperCase(),
          style: GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? AppTheme.cyberCyan : AppTheme.textMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomActionBar(PoseAnalysisState state) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.cardBorderColor, width: 1.2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'EXERCISE ACTIVE',
                  style: GoogleFonts.outfit(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textMuted,
                    letterSpacing: 1.0,
                  ),
                ),
                Text(
                  state.exerciseName.toUpperCase(),
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: state.isSaving ? null : _triggerFinish,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Ink(
              decoration: BoxDecoration(
                gradient: AppTheme.secondaryGradient,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                child: Row(
                  children: [
                    if (state.isSaving)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    else
                      const Icon(Icons.emoji_events_outlined, color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'FINISH SESSION',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(int elapsed) {
    final m = (elapsed ~/ 60).toString().padLeft(2, '0');
    final s = (elapsed % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

// ─── POSE SKELETON CUSTOM PAINTER ───────────────────────────────────────────

class PosePainter extends CustomPainter {
  final Map<PoseLandmarkType, PoseLandmark> landmarks;
  final Size imageSize;
  final InputImageRotation rotation;
  final bool isFrontCamera;

  PosePainter(this.landmarks, this.imageSize, this.rotation, this.isFrontCamera);

  @override
  void paint(Canvas canvas, Size size) {
    if (landmarks.isEmpty) return;

    final paintJoint = Paint()
      ..color = AppTheme.cyberCyan
      ..strokeWidth = 6.0
      ..style = PaintingStyle.fill;

    final paintLine = Paint()
      ..color = AppTheme.electricBlue.withValues(alpha: 0.8)
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    // Standard scale translation (camera format preview size orientation layout mapping)
    Offset translate(PoseLandmark landmark) {
      double x = landmark.x;
      double y = landmark.y;

      // Handle front camera mirroring
      if (isFrontCamera) {
        x = imageSize.width - x;
      }

      // Portrait rotation swapping scale calculations
      final scaleX = size.width / imageSize.height;
      final scaleY = size.height / imageSize.width;

      final double tempX = x;
      x = y;
      y = imageSize.width - tempX;

      return Offset(x * scaleX, y * scaleY);
    }

    void drawConnection(PoseLandmarkType t1, PoseLandmarkType t2) {
      final p1 = landmarks[t1];
      final p2 = landmarks[t2];
      if (p1 != null && p2 != null) {
        canvas.drawLine(translate(p1), translate(p2), paintLine);
      }
    }

    // Draw main body skeleton skeletal lines
    drawConnection(PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder);
    drawConnection(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip);
    drawConnection(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip);
    drawConnection(PoseLandmarkType.leftHip, PoseLandmarkType.rightHip);

    // Left limbs
    drawConnection(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow);
    drawConnection(PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist);
    drawConnection(PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee);
    drawConnection(PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle);

    // Right limbs
    drawConnection(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow);
    drawConnection(PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist);
    drawConnection(PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee);
    drawConnection(PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle);

    // Draw joint point circles
    landmarks.forEach((type, landmark) {
      // Limit drawing points to major key training joints to keep canvas uncluttered
      if (type == PoseLandmarkType.leftShoulder ||
          type == PoseLandmarkType.rightShoulder ||
          type == PoseLandmarkType.leftElbow ||
          type == PoseLandmarkType.rightElbow ||
          type == PoseLandmarkType.leftWrist ||
          type == PoseLandmarkType.rightWrist ||
          type == PoseLandmarkType.leftHip ||
          type == PoseLandmarkType.rightHip ||
          type == PoseLandmarkType.leftKnee ||
          type == PoseLandmarkType.rightKnee ||
          type == PoseLandmarkType.leftAnkle ||
          type == PoseLandmarkType.rightAnkle) {
        canvas.drawCircle(translate(landmark), 4.0, paintJoint);
      }
    });
  }

  @override
  bool shouldRepaint(covariant PosePainter oldDelegate) {
    return oldDelegate.landmarks != landmarks;
  }
}
