import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'api_constants.dart';
import '../../features/workouts/data/models/ai_workout_models.dart';
import '../../features/chat/data/models/chat_message_model.dart';
import 'dart:developer' as developer;

class ApiClient {
  final Dio _dio;

  ApiClient({Dio? dio}) : _dio = dio ?? Dio() {
    _dio.options.baseUrl = ApiConstants.baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 8);
    _dio.options.receiveTimeout = const Duration(seconds: 15);

    // Dynamic Firebase JWT Interceptor
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          try {
            final user = fb.FirebaseAuth.instance.currentUser;
            if (user != null) {
              final token = await user.getIdToken(false).timeout(
                const Duration(seconds: 3),
                onTimeout: () => null,
              );
              if (token != null && token.trim().isNotEmpty) {
                options.headers['Authorization'] = 'Bearer ${token.trim()}';
              }
            }
          } catch (e) {
            debugPrint('Error attaching Firebase token to request: $e');
          }
          return handler.next(options);
        },
      ),
    );
  }

  /// Personalized AI Workout Planner (POST /api/ai-workout)
  Future<AiWorkoutResponse> generateAiWorkout(AiWorkoutRequest request) async {
    try {
      final response = await _dio.post(
        ApiConstants.aiWorkout,
        data: request.toJson(),
      );

      if (response.statusCode == 200 && response.data != null) {
        return AiWorkoutResponse.fromJson(response.data as Map<String, dynamic>);
      } else {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          message: 'Failed to generate workout plan: ${response.statusMessage}',
        );
      }
    } catch (e) {
      if (e is DioException) {
        developer.log(
          'DioException in generateAiWorkout: [Type: ${e.type}] [Status: ${e.response?.statusCode}] [Body: ${e.response?.data}] [Msg: ${e.message}]',
          name: 'ApiClient',
          error: e,
        );
      } else {
        developer.log(
          'Error generating workout: $e',
          name: 'ApiClient',
          error: e,
        );
      }
      debugPrint('Error generating workout: $e. Falling back to local AI simulator.');
      return _generateSimulatedWorkoutResponse(request);
    }
  }

  /// AI Coach Chat Stream (directly uses local simulator)
  Stream<String> streamChat(List<ChatMessageModel> messages) async* {
    yield* streamSimulatedChatResponse(messages);
  }

  /// Global Dynamic YouTube Video Tutorial Resolver for Sandbox & Fallback imports
  static String resolveWorkoutVideoUrl(String title) {
    final lower = title.toLowerCase();
    if (lower.contains('bench press')) {
      return 'https://www.youtube.com/watch?v=rT7DgCr-3pg';
    } else if (lower.contains('push-up') || lower.contains('push up')) {
      return 'https://www.youtube.com/watch?v=IODxDxX7oi4';
    } else if (lower.contains('tricep extension') || lower.contains('tricep')) {
      return 'https://www.youtube.com/watch?v=X-iV-sGEL1s';
    } else if (lower.contains('squat')) {
      return 'https://www.youtube.com/watch?v=aclHkVaku9U';
    } else if (lower.contains('calf raise') || lower.contains('calf')) {
      return 'https://www.youtube.com/watch?v=YM21oT-Vyc4';
    } else if (lower.contains('pull-up') || lower.contains('pull up') || lower.contains('lat')) {
      return 'https://www.youtube.com/watch?v=eGo4IYlbE5g';
    } else if (lower.contains('plank')) {
      return 'https://www.youtube.com/watch?v=B296mZDhrWY';
    } else if (lower.contains('deadlift')) {
      return 'https://www.youtube.com/watch?v=XowK9_K25VA';
    }
    // Generic backup workout tutorial
    return 'https://www.youtube.com/watch?v=aclHkVaku9U';
  }

  /// High-fidelity local AI workout plan generator fallback
  AiWorkoutResponse _generateSimulatedWorkoutResponse(AiWorkoutRequest request) {
    final lowerFocus = request.focus.toLowerCase();
    String routineName = 'AI Cyber-Plat ${request.focus}';
    String summary = 'A biomechanically optimized routine tailored for ${request.experience} level targeting ${request.focus} with a goal of ${request.goal}.';
    List<AiWorkoutExercise> exercises = [];
    List<String> warnings = [];

    if (request.injuries.toLowerCase() != 'none') {
      warnings.add('Form adjustment active: Avoid overloading joints affected by injury: ${request.injuries}.');
    }
    warnings.add('Ensure camera scanning is active during deep flexions.');

    if (lowerFocus.contains('push') || lowerFocus.contains('chest') || lowerFocus.contains('upper')) {
      routineName = 'Neural Upper Push Core';
      exercises = [
        AiWorkoutExercise(
          name: 'Barbell Bench Press',
          sets: 4,
          reps: '10 reps',
          weightKg: '40 kg',
          rest: '90s',
          notes: 'Keep shoulders retracted. Scan alignment path with camera overlay.',
        ),
        AiWorkoutExercise(
          name: 'Push-Up',
          sets: 3,
          reps: '12 reps',
          weightKg: 'Bodyweight',
          rest: '60s',
          notes: 'Full lock at top. Keep core tight.',
        ),
        AiWorkoutExercise(
          name: 'Overhead Dumbbell Tricep Extension',
          sets: 3,
          reps: '10 reps',
          weightKg: '10 kg',
          rest: '60s',
          notes: 'Avoid elbow flaring.',
        ),
      ];
    } else if (lowerFocus.contains('pull') || lowerFocus.contains('back')) {
      routineName = 'Neural Pull & Lats Developer';
      exercises = [
        AiWorkoutExercise(
          name: 'Pull-Up',
          sets: 4,
          reps: '8 reps',
          weightKg: 'Bodyweight',
          rest: '90s',
          notes: 'Drive elbows down, squeeze shoulder blades.',
        ),
        AiWorkoutExercise(
          name: 'Push-Up',
          sets: 3,
          reps: '12 reps',
          weightKg: 'Bodyweight',
          rest: '60s',
          notes: 'Secondary compound pull support core lock.',
        ),
      ];
    } else if (lowerFocus.contains('leg') || lowerFocus.contains('lower') || lowerFocus.contains('quad')) {
      routineName = 'Neural Lower Body Optimizer';
      exercises = [
        AiWorkoutExercise(
          name: 'Bodyweight Squat',
          sets: 4,
          reps: '12 reps',
          weightKg: 'Bodyweight',
          rest: '90s',
          notes: 'Sit deep. Keep back straight and check hip flexion on pose analyzer.',
        ),
        AiWorkoutExercise(
          name: 'Standing Calf Raise',
          sets: 3,
          reps: '15 reps',
          weightKg: '10 kg',
          rest: '60s',
          notes: 'Full extension at top.',
        ),
      ];
    } else {
      // Default Full Body
      routineName = 'AI 360 Full Body Calibrator';
      exercises = [
        AiWorkoutExercise(
          name: 'Bodyweight Squat',
          sets: 3,
          reps: '12 reps',
          weightKg: 'Bodyweight',
          rest: '90s',
          notes: 'Sit deep, hips past knees.',
        ),
        AiWorkoutExercise(
          name: 'Push-Up',
          sets: 3,
          reps: '12 reps',
          weightKg: 'Bodyweight',
          rest: '60s',
          notes: 'Keep straight back alignment.',
        ),
        AiWorkoutExercise(
          name: 'Forearm Plank',
          sets: 3,
          reps: '60 seconds',
          weightKg: 'Bodyweight',
          rest: '45s',
          notes: 'Hold flat body alignment. Engage core.',
        ),
      ];
    }

    return AiWorkoutResponse(
      routine: AiWorkoutRoutine(
        routineName: routineName,
        summary: summary,
        exercises: exercises,
        warnings: warnings,
      ),
    );
  }

  /// High-fidelity local AI Coach chatbot simulator fallback
  Stream<String> streamSimulatedChatResponse(List<ChatMessageModel> messages) async* {
    final userPrompt = messages.isNotEmpty ? messages.last.content : '';
    final lowerPrompt = userPrompt.toLowerCase();
    final isArabic = RegExp(r'[\u0600-\u06FF]').hasMatch(userPrompt);
    String responseText = '';

    if (isArabic) {
      if (lowerPrompt.contains('برنامج') || lowerPrompt.contains('تمرين') || lowerPrompt.contains('خطة') || lowerPrompt.contains('جدول')) {
        responseText = 'أهلاً بك في Core-360! 🌌 أنا مدربك الشخصي بالذكاء الاصطناعي.\n\nلقد قمت بتحليل طلبك وبنيتك البدنية، وأقترح عليك هذه الخطة التدريبية المحسنة للأداء العالي وتفادي الإصابات:\n\n'
            '[PLAN_PROPOSAL]\n'
            '{\n'
            '  "name": "خطة Core-360 للتحمل والفتنس",\n'
            '  "exercises": [\n'
            '    {\n'
            '      "workoutId": "squats_003",\n'
            '      "title": "Bodyweight Squat",\n'
            '      "sets": [\n'
            '        {"reps": 12, "kg": 0.0},\n'
            '        {"reps": 12, "kg": 0.0},\n'
            '        {"reps": 12, "kg": 0.0}\n'
            '      ],\n'
            '      "order": 0\n'
            '    },\n'
            '    {\n'
            '      "workoutId": "push_ups_002",\n'
            '      "title": "Push-Up",\n'
            '      "sets": [\n'
            '        {"reps": 10, "kg": 0.0},\n'
            '        {"reps": 10, "kg": 0.0}\n'
            '      ],\n'
            '      "order": 1\n'
            '    },\n'
            '    {\n'
            '      "workoutId": "plank_005",\n'
            '      "title": "Forearm Plank",\n'
            '      "sets": [\n'
            '        {"reps": 1, "kg": 0.0}\n'
            '      ],\n'
            '      "order": 2\n'
            '    }\n'
            '  ]\n'
            '}\n'
            '[/PLAN_PROPOSAL]\n\n'
            'يمكنك الضغط على البطاقة أعلاه لإضافة هذا الجدول التدريبي مباشرة إلى مكتبة تمارينك والبدء في تتبعه فوراً باستخدام الكاميرا الذكية لتحليل المفاصل.';
      } else {
        responseText = 'أهلاً بك! أنا مدربك الرياضي الشخصي الذكي من Core-360. 🏋️‍♂️\n\nكيف يمكنني مساعدتك اليوم؟ يمكنك سؤالي عن كيفية أداء التمارين بشكل صحيح، أو طلب خطة تدريبية مخصصة، أو استشارتي حول التغذية وتفادي الإصابات أثناء التمرين!';
      }
    } else {
      if (lowerPrompt.contains('plan') || lowerPrompt.contains('routine') || lowerPrompt.contains('workout') || lowerPrompt.contains('schedule') || lowerPrompt.contains('generate')) {
        responseText = 'Welcome to the Core-360 Neural Coaching Sandbox! 🌌 I have compiled a premium biomechanically-safe routine based on your request and historical statistics.\n\nHere is your custom workout proposal designed to build lean volume and bypass joint stress:\n\n'
            '[PLAN_PROPOSAL]\n'
            '{\n'
            '  "name": "AI Cyber-Plank Conditioning",\n'
            '  "exercises": [\n'
            '    {\n'
            '      "workoutId": "squats_003",\n'
            '      "title": "Bodyweight Squat",\n'
            '      "sets": [\n'
            '        {"reps": 12, "kg": 0.0},\n'
            '        {"reps": 12, "kg": 0.0},\n'
            '        {"reps": 12, "kg": 0.0}\n'
            '      ],\n'
            '      "order": 0\n'
            '    },\n'
            '    {\n'
            '      "workoutId": "push_ups_002",\n'
            '      "title": "Push-Up",\n'
            '      "sets": [\n'
            '        {"reps": 12, "kg": 0.0},\n'
            '        {"reps": 12, "kg": 0.0}\n'
            '      ],\n'
            '      "order": 1\n'
            '    },\n'
            '    {\n'
            '      "workoutId": "plank_005",\n'
            '      "title": "Forearm Plank",\n'
            '      "sets": [\n'
            '        {"reps": 1, "kg": 0.0}\n'
            '      ],\n'
            '      "order": 2\n'
            '    }\n'
            '  ]\n'
            '}\n'
            '[/PLAN_PROPOSAL]\n\n'
            'You can tap the card above to immediately import this routine into your personal library and launch it with live computer vision joint flexion warnings!';
      } else {
        responseText = 'Welcome to Core-360 Neural Coaching! 🌌 I am your dedicated AI fitness companion.\n\nAsk me anything about proper joint alignment, squat depth calculations, or request a custom workout split tailored to bypass physical limits!';
      }
    }

    final words = responseText.split(' ');
    for (int i = 0; i < words.length; i++) {
      yield '${words[i]} ';
      await Future.delayed(const Duration(milliseconds: 30));
    }
  }

  /// Fetch Chat History (GET /api/chat)
  Future<List<ChatMessageModel>> getChatHistory() async {
    try {
      final response = await _dio.get(ApiConstants.chat);

      if (response.statusCode == 200 && response.data != null) {
        final list = response.data as List? ?? [];
        return list
            .map((item) => ChatMessageModel.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList();
      } else {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          message: 'Failed to fetch chat history: ${response.statusMessage}',
        );
      }
    } catch (e) {
      debugPrint('Error fetching chat history: $e');
      return [];
    }
  }

  /// Sends a Chat Completion request to Groq Cloud API
  Future<Map<String, dynamic>> getChatCompletion({
    required String systemPrompt,
    required String userPrompt,
    String? apiKey,
  }) async {
    final key = apiKey ?? const String.fromEnvironment('GROQ_API_KEY');
    
    if (key.isEmpty || key == 'MOCK_MODE') {
      debugPrint('Groq API Key is empty. Falling back to local AI Simulator.');
      return _generateSimulatedResponse(userPrompt);
    }

    try {
      final response = await _dio.post(
        'https://api.groq.com/openai/v1/chat/completions',
        options: Options(
          headers: {
            'Authorization': 'Bearer $key',
            'Content-Type': 'application/json',
          },
        ),
        data: {
          'model': 'llama-3.3-70b-versatile',
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': userPrompt},
          ],
          'temperature': 0.3,
          'response_format': {'type': 'json_object'},
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        return response.data as Map<String, dynamic>;
      } else {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          message: 'Failed to query Groq: ${response.statusMessage}',
        );
      }
    } catch (e) {
      debugPrint('Groq API query failed: $e. Falling back to simulator.');
      return _generateSimulatedResponse(userPrompt);
    }
  }

  /// Generates a local mock response matching the required schema if Groq is unavailable.
  Map<String, dynamic> _generateSimulatedResponse(String userPrompt) {
    String routineName = 'AI Generated Custom Routine';
    List<Map<String, dynamic>> selectedExercises = [];

    final lowerPrompt = userPrompt.toLowerCase();
    
    if (lowerPrompt.contains('lower') || lowerPrompt.contains('quadriceps') || lowerPrompt.contains('lower body')) {
      routineName = 'AI Leg & Core Developer';
      if (!lowerPrompt.contains('knee')) {
        selectedExercises.add({
          'workoutId': 'squats_003',
          'title': 'Bodyweight Squat',
          'sets': [
            {'reps': 12, 'kg': 0.0},
            {'reps': 12, 'kg': 0.0},
            {'reps': 12, 'kg': 0.0},
          ],
          'order': 0,
        });
      }
      if (!lowerPrompt.contains('lower back')) {
        selectedExercises.add({
          'workoutId': 'romanian_deadlift_009',
          'title': 'Romanian Deadlift',
          'sets': [
            {'reps': 10, 'kg': 20.0},
            {'reps': 10, 'kg': 20.0},
            {'reps': 10, 'kg': 20.0},
          ],
          'order': selectedExercises.length,
        });
      }
      selectedExercises.add({
        'workoutId': 'calve_raises_010',
        'title': 'Standing Calf Raise',
        'sets': [
          {'reps': 15, 'kg': 10.0},
          {'reps': 15, 'kg': 10.0},
        ],
        'order': selectedExercises.length,
      });
    } else if (lowerPrompt.contains('upper') || lowerPrompt.contains('chest') || lowerPrompt.contains('push')) {
      routineName = 'AI Chest & Triceps Push';
      if (!lowerPrompt.contains('shoulder')) {
        selectedExercises.add({
          'workoutId': 'bench_press_001',
          'title': 'Barbell Bench Press',
          'sets': [
            {'reps': 8, 'kg': 40.0},
            {'reps': 8, 'kg': 40.0},
            {'reps': 8, 'kg': 40.0},
          ],
          'order': 0,
        });
      }
      selectedExercises.add({
        'workoutId': 'push_ups_002',
        'title': 'Push-Up',
        'sets': [
          {'reps': 12, 'kg': 0.0},
          {'reps': 12, 'kg': 0.0},
        ],
        'order': selectedExercises.length,
      });
      selectedExercises.add({
        'workoutId': 'tricep_extension_007',
        'title': 'Overhead Dumbbell Tricep Extension',
        'sets': [
          {'reps': 10, 'kg': 7.5},
          {'reps': 10, 'kg': 7.5},
        ],
        'order': selectedExercises.length,
      });
    } else {
      routineName = 'AI Full-Body Calibrator';
      if (!lowerPrompt.contains('knee')) {
        selectedExercises.add({
          'workoutId': 'squats_003',
          'title': 'Bodyweight Squat',
          'sets': [
            {'reps': 12, 'kg': 0.0},
            {'reps': 12, 'kg': 0.0},
          ],
          'order': 0,
        });
      }
      selectedExercises.add({
        'workoutId': 'push_ups_002',
        'title': 'Push-Up',
        'sets': [
          {'reps': 12, 'kg': 0.0},
          {'reps': 12, 'kg': 0.0},
        ],
        'order': selectedExercises.length,
      });
      if (!lowerPrompt.contains('shoulder')) {
        selectedExercises.add({
          'workoutId': 'pull_ups_004',
          'title': 'Pull-Up',
          'sets': [
            {'reps': 8, 'kg': 0.0},
            {'reps': 8, 'kg': 0.0},
          ],
          'order': selectedExercises.length,
        });
      }
      selectedExercises.add({
        'workoutId': 'plank_005',
        'title': 'Forearm Plank',
        'sets': [
          {'reps': 1, 'kg': 0.0},
        ],
        'order': selectedExercises.length,
      });
    }

    return {
      'choices': [
        {
          'message': {
            'content': '''{
              "name": "$routineName",
              "exercises": ${StreamMappingHelper.flatJsonExercises(selectedExercises)}
            }'''
          }
        }
      ]
    };
  }
}

class StreamMappingHelper {
  static String flatJsonExercises(List<Map<String, dynamic>> list) {
    final buffer = StringBuffer('[');
    for (int i = 0; i < list.length; i++) {
      final item = list[i];
      final setsStr = (item['sets'] as List).map((s) => '{"reps": ${s['reps']}, "kg": ${s['kg']}}').join(', ');
      buffer.write('{');
      buffer.write('"workoutId": "${item['workoutId']}",');
      buffer.write('"title": "${item['title']}",');
      buffer.write('"sets": [$setsStr],');
      buffer.write('"order": ${item['order']}');
      buffer.write('}');
      if (i < list.length - 1) buffer.write(',');
    }
    buffer.write(']');
    return buffer.toString();
  }
}

// ─── RIVERPOD PROVIDER ──────────────────────────────────────────────

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());
