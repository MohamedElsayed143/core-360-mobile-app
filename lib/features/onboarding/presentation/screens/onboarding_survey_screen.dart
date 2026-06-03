import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/entities/user_profile.dart';
import '../providers/auth_provider.dart';

class OnboardingSurveyScreen extends ConsumerStatefulWidget {
  const OnboardingSurveyScreen({super.key});

  @override
  ConsumerState<OnboardingSurveyScreen> createState() =>
      _OnboardingSurveyScreenState();
}

class _OnboardingSurveyScreenState
    extends ConsumerState<OnboardingSurveyScreen> {
  int _currentStep = 1;
  final _step1FormKey = GlobalKey<FormState>();

  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();

  final _bodyFatController = TextEditingController();
  final _waterPercentageController = TextEditingController();
  final _muscleMassController = TextEditingController();

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
        setState(() => _currentStep = 2);
      }
    } else if (_currentStep == 2) {
      setState(() => _currentStep = 3);
    }
  }

  void _previousStep() {
    if (_currentStep > 1) {
      setState(() => _currentStep--);
    }
  }

  void _submitSurvey() {
    if (_selectedGoals.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.orangeAccent,
          content: Text(
            'Please select at least one primary fitness goal.',
            style: GoogleFonts.outfit(
                color: Colors.black, fontWeight: FontWeight.bold),
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
      injuries: _injuriesController.text.trim().isEmpty
          ? null
          : _injuriesController.text.trim(),
    );

    ref.read(authProvider.notifier).submitOnboarding(profile);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF121824), Color(0xFF1a1224)],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
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
                        color: const Color(0xFF22c55e),
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28.0),
                child: Stack(
                  children: [
                    Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: const Color(0xFF323b49),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: MediaQuery.of(context).size.width *
                              (_currentStep / 3.0) -
                          56,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 36),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 28.0),
                  child: _buildCurrentFormStep(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(28.0),
                child: Row(
                  children: [
                    if (_currentStep > 1)
                      Expanded(
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: const Color(0xFF3d4d6b), width: 0.5),
                          ),
                          child: OutlinedButton(
                            onPressed: _previousStep,
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              side: BorderSide.none,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              'BACK',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFFe2e8f0),
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (_currentStep > 1) const SizedBox(width: 16),
                    Expanded(
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ElevatedButton(
                          onPressed: _currentStep == 3
                              ? _submitSurvey
                              : _nextStep,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
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

  Widget _buildStep1CoreBiometrics() {
    return Form(
      key: _step1FormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'We require your basic parameters to configure precise load weights and metabolic thresholds.',
            style: GoogleFonts.outfit(
              color: const Color(0xFF94a3b8),
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          _buildLabel('Age (Years)'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _ageController,
            keyboardType: TextInputType.number,
            style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
            decoration: _inputDecoration('e.g. 28'),
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
          _buildLabel('Height (cm)'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _heightController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
            decoration: _inputDecoration('e.g. 178'),
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
          _buildLabel('Weight (kg)'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _weightController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
            decoration: _inputDecoration('e.g. 75.5'),
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

  Widget _buildStep2AdvancedMetrics() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Enter optional metrics to fine-tune active physical load volumes, or skip forward.',
          style: GoogleFonts.outfit(
            color: const Color(0xFF94a3b8),
            fontSize: 14,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: TextButton.icon(
            onPressed: () {
              _bodyFatController.clear();
              _waterPercentageController.clear();
              _muscleMassController.clear();
              setState(() => _currentStep = 3);
            },
            icon: const Icon(Icons.fast_forward,
                color: Color(0xFF22c55e), size: 20),
            label: Text(
              'SKIP ALL METRICS',
              style: GoogleFonts.outfit(
                color: const Color(0xFF22c55e),
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        _buildLabel('Body Fat (%)'),
        const SizedBox(height: 8),
        TextFormField(
          controller: _bodyFatController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
          decoration: _inputDecoration('Optional (e.g. 15.4)'),
        ),
        const SizedBox(height: 20),
        _buildLabel('Body Water (%)'),
        const SizedBox(height: 8),
        TextFormField(
          controller: _waterPercentageController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
          decoration: _inputDecoration('Optional (e.g. 60.5)'),
        ),
        const SizedBox(height: 20),
        _buildLabel('Muscle Mass (kg)'),
        const SizedBox(height: 8),
        TextFormField(
          controller: _muscleMassController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
          decoration: _inputDecoration('Optional (e.g. 35.8)'),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildStep3GoalsSafety() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Select your primary target objectives and let us know about any physical injury histories for safer workout planning.',
          style: GoogleFonts.outfit(
            color: const Color(0xFF94a3b8),
            fontSize: 14,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 32),
        _buildLabel('PRIMARY OBJECTIVES'),
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
                  color:
                      isSelected ? Colors.black : const Color(0xFFe2e8f0),
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
              selectedColor: Colors.white,
              checkmarkColor: Colors.black,
              backgroundColor: const Color(0xFF323b49),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: isSelected
                      ? Colors.white
                      : const Color(0xFF3d4a5e).withValues(alpha: 0.5),
                  width: 0.5,
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 36),
        _buildLabel('PRE-EXISTING INJURIES & PHYSICAL ALERTS'),
        const SizedBox(height: 12),
        TextFormField(
          controller: _injuriesController,
          maxLines: 4,
          style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
          decoration: _inputDecoration(
            'e.g. Left shoulder rotator cuff tear, lumbar spine disk bulge. Leave blank if none.',
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.outfit(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: const Color(0xFFe2e8f0),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      filled: true,
      fillColor: const Color(0xFF323b49),
      hintText: hint,
      hintStyle:
          GoogleFonts.outfit(color: const Color(0xFF94a3b8), fontSize: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
            color: const Color(0xFF3d4a5e).withValues(alpha: 0.5), width: 0.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
            color: const Color(0xFF3d4a5e).withValues(alpha: 0.5), width: 0.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: const Color(0xFF94a3b8), width: 1),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}
