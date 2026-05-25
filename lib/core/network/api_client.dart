import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ApiClient {
  final Dio _dio;

  ApiClient({Dio? dio}) : _dio = dio ?? Dio() {
    _dio.options.connectTimeout = const Duration(seconds: 15);
    _dio.options.receiveTimeout = const Duration(seconds: 15);
  }

  /// Sends a Chat Completion request to Groq Cloud API
  Future<Map<String, dynamic>> getChatCompletion({
    required String systemPrompt,
    required String userPrompt,
    String? apiKey,
  }) async {
    // 1. Resolve API key from arguments, environment variables, or fallback
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
    // Determine split or goal from prompt text to make the simulation dynamic
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
      // Full Body default simulation
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
          {'reps': 1, 'kg': 0.0}, // Plank reps represent minutes or holds
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
