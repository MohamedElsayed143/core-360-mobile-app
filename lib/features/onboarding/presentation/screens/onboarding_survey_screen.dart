import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:core_360_app/core/theme/app_theme.dart';
import '../../domain/entities/user_profile.dart';
import '../providers/auth_provider.dart';

class OnboardingSurveyScreen extends ConsumerStatefulWidget {
  const OnboardingSurveyScreen({super.key});

  @override
  ConsumerState<OnboardingSurveyScreen> createState() => _OnboardingSurveyScreenState();
}

class _OnboardingSurveyScreenState extends ConsumerState<OnboardingSurveyScreen> {
  int _currentStep = 1;
  final _step1FormKey = GlobalKey<FormState>();

  // Step 1 Controllers
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();

  // Step 2 Controllers (Optional)
  final _bodyFatController = TextEditingController();
  final _waterPercentageController = TextEditingController();
  final _muscleMassController = TextEditingController();

  // Step 3 Data
  final List<String> _selectedGoals = [];
  final _injuriesController = TextEditingController();

  final List<String> _availableGoals = [
    'Muscle Gain',
    'Weight Loss',
    'Posture Correction',
    'Flexibility',
    'Endurance'
  ];

  @override
  void dispose() {
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _bodyFatController.dispose();
    _waterPercentageController.dispose();
    _muscleMassController.dispose();
    _injuriesController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep == 1) {
      if (_step1FormKey.currentState!.validate()) {
        setState(() {
          _currentStep = 2;
        });
      }
    } else if (_currentStep == 2) {
      setState(() {
        _currentStep = 3;
      });
    }
  }

  void _previousStep() {
    if (_currentStep > 1) {
      setState(() {
        _currentStep--;
      });
    }
  }

  void _submitSurvey() {
    if (_selectedGoals.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.orangeAccent,
          content: Text(
            'Please select at least one primary fitness goal.',
            style: GoogleFonts.outfit(color: Colors.black, fontWeight: FontWeight.bold),
          ),
        ),
      );
      return;
    }

    final age = int.parse(_ageController.text);
    final height = double.parse(_heightController.text);
    final weight = double.parse(_weightController.text);

    final bodyFat = double.tryParse(_bodyFatController.text);
    final waterPercentage = double.tryParse(_waterPercentageController.text);
    final muscleMass = double.tryParse(_muscleMassController.text);

    final profile = UserProfile(
      age: age,
      height: height,
      weight: weight,
      bodyFat: bodyFat,
      waterPercentage: waterPercentage,
      muscleMass: muscleMass,
      goals: _selectedGoals,
      injuries: _injuriesController.text.trim().isEmpty ? null : _injuriesController.text.trim(),
    );

    ref.read(authProvider.notifier).submitOnboarding(profile);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      body: Stack(
        children: [
          // ─── AMBIENT BACKGROUND GLOWS ────────────────────────────────────
          Positioned(
            top: -120,
            left: -120,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.cyberCyan.withOpacity(0.08),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.cyberCyan.withOpacity(0.06),
                    blurRadius: 150,
                    spreadRadius: 80,
                  )
                ],
              ),
            ),
          ),

          // ─── SAFE AREA BODY ──────────────────────────────────────────────
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                
                // ─── PROGRESS HEADERS ──────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Step $_currentStep of 3',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.cyberCyan,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getStepTitle(),
                        style: GoogleFonts.outfit(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // ─── GLOWING DYNAMIC PROGRESS BAR ──────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28.0),
                  child: Stack(
                    children: [
                      Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: AppTheme.cardBorderColor,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: MediaQuery.of(context).size.width * (_currentStep / 3.0) - 56,
                        height: 6,
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(3),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.cyberCyan.withOpacity(0.4),
                              blurRadius: 10,
                            )
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 36),

                // ─── CONTENT FORM VIEWS ────────────────────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 28.0),
                    child: _buildCurrentFormStep(),
                  ),
                ),

                // ─── NAVIGATION FOOTER ─────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.all(28.0),
                  child: Row(
                    children: [
                      if (_currentStep > 1)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _previousStep,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: const BorderSide(color: AppTheme.cardBorderColor),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              'BACK',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                        ),
                      if (_currentStep > 1) const SizedBox(width: 16),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: AppTheme.primaryGradient,
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.cyberCyan.withOpacity(0.2),
                                blurRadius: 14,
                                offset: const Offset(0, 3),
                              )
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: _currentStep == 3 ? _submitSurvey : _nextStep,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              _currentStep == 3 ? 'FINISH' : 'NEXT',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ─── ACTION HUD LOADER ───────────────────────────────────────────
          if (authState is AuthLoading)
            Container(
              color: Colors.black.withOpacity(0.7),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: AppTheme.darkSurface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppTheme.cardBorderColor, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.cyberCyan.withOpacity(0.1),
                        blurRadius: 40,
                      )
                    ],
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.cyberCyan),
                        strokeWidth: 3.5,
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

  String _getStepTitle() {
    switch (_currentStep) {
      case 1:
        return 'Core Biometrics';
      case 2:
        return 'Advanced (Optional)';
      case 3:
        return 'Goals & Safety';
      default:
        return '';
    }
  }

  Widget _buildCurrentFormStep() {
    switch (_currentStep) {
      case 1:
        return _buildStep1CoreBiometrics();
      case 2:
        return _buildStep2AdvancedMetrics();
      case 3:
        return _buildStep3GoalsSafety();
      default:
        return const SizedBox.shrink();
    }
  }

  // ─── STEP 1 Core Biometrics ────────────────────────────────────────
  Widget _buildStep1CoreBiometrics() {
    return Form(
      key: _step1FormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'We require your basic parameters to configure precise load weights and metabolic thresholds.',
            style: GoogleFonts.outfit(color: Colors.white70, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 32),

          // AGE
          TextFormField(
            controller: _ageController,
            keyboardType: TextInputType.number,
            style: GoogleFonts.outfit(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Age (Years)',
              prefixIcon: Icon(Icons.cake_outlined, color: Colors.white70),
              hintText: 'e.g. 28',
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your age';
              }
              final parsed = int.tryParse(value);
              if (parsed == null || parsed < 10 || parsed > 120) {
                return 'Age must be between 10 and 120';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),

          // HEIGHT
          TextFormField(
            controller: _heightController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: GoogleFonts.outfit(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Height (cm)',
              prefixIcon: Icon(Icons.height, color: Colors.white70),
              hintText: 'e.g. 178',
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your height';
              }
              final parsed = double.tryParse(value);
              if (parsed == null || parsed < 100 || parsed > 250) {
                return 'Height must be between 100 and 250 cm';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),

          // WEIGHT
          TextFormField(
            controller: _weightController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: GoogleFonts.outfit(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Weight (kg)',
              prefixIcon: Icon(Icons.monitor_weight_outlined, color: Colors.white70),
              hintText: 'e.g. 75.5',
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your weight';
              }
              final parsed = double.tryParse(value);
              if (parsed == null || parsed < 30 || parsed > 300) {
                return 'Weight must be between 30 and 300 kg';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ─── STEP 2 Advanced (Optional) ────────────────────────────────────
  Widget _buildStep2AdvancedMetrics() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Enter optional metrics to fine-tune active physical load volumes, or skip forward.',
                style: GoogleFonts.outfit(color: Colors.white70, fontSize: 14, height: 1.5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Center(
          child: TextButton.icon(
            onPressed: () {
              // Clear values and proceed
              _bodyFatController.clear();
              _waterPercentageController.clear();
              _muscleMassController.clear();
              setState(() {
                _currentStep = 3;
              });
            },
            icon: const Icon(Icons.fast_forward, color: AppTheme.amethystPurple),
            label: Text(
              'SKIP ALL METRICS',
              style: GoogleFonts.outfit(
                color: AppTheme.amethystPurple,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // BODY FAT %
        TextFormField(
          controller: _bodyFatController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: GoogleFonts.outfit(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Body Fat (%)',
            prefixIcon: Icon(Icons.percent, color: Colors.white70),
            hintText: 'Optional (e.g. 15.4)',
          ),
        ),
        const SizedBox(height: 20),

        // WATER %
        TextFormField(
          controller: _waterPercentageController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: GoogleFonts.outfit(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Body Water (%)',
            prefixIcon: Icon(Icons.opacity, color: Colors.white70),
            hintText: 'Optional (e.g. 60.5)',
          ),
        ),
        const SizedBox(height: 20),

        // MUSCLE MASS (kg)
        TextFormField(
          controller: _muscleMassController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: GoogleFonts.outfit(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Muscle Mass (kg)',
            prefixIcon: Icon(Icons.fitness_center_outlined, color: Colors.white70),
            hintText: 'Optional (e.g. 35.8)',
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  // ─── STEP 3 Goals & Safety ─────────────────────────────────────────
  Widget _buildStep3GoalsSafety() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Select your primary target objectives and let us know about any physical injury histories for safer workout planning.',
          style: GoogleFonts.outfit(color: Colors.white70, fontSize: 14, height: 1.5),
        ),
        const SizedBox(height: 32),

        // GOALS CHIPS SECTION
        Text(
          'PRIMARY OBJECTIVES (SELECT ALL THAT APPLY):',
          style: GoogleFonts.outfit(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
            color: Colors.white54,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _availableGoals.map((goal) {
            final isSelected = _selectedGoals.contains(goal);
            return FilterChip(
              label: Text(
                goal,
                style: GoogleFonts.outfit(
                  color: isSelected ? Colors.black : Colors.white70,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedGoals.add(goal);
                  } else {
                    _selectedGoals.remove(goal);
                  }
                });
              },
              selectedColor: AppTheme.cyberCyan,
              checkmarkColor: Colors.black,
              backgroundColor: AppTheme.glassFillColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isSelected ? AppTheme.cyberCyan : AppTheme.cardBorderColor,
                  width: 1.2,
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 36),

        // INJURIES INPUT
        Text(
          'PRE-EXISTING INJURIES & PHYSICAL ALERTS:',
          style: GoogleFonts.outfit(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
            color: Colors.white54,
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _injuriesController,
          maxLines: 4,
          style: GoogleFonts.outfit(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'e.g. Left shoulder rotator cuff tear, lumbar spine disk bulge. Leave blank if none.',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
