import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../../core/network/models/workout_data.dart';
import 'api_constants.dart';
import '../../features/workouts/data/models/ai_workout_models.dart';
import '../../features/chat/data/models/chat_message_model.dart';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math';

class ApiClient {
  final Dio _dio;

  // Cache for workouts fetched from backend
  Map<String, WorkoutData>? _workoutsCache;
  bool _isFetchingWorkouts = false;
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
              final token = await user
                  .getIdToken(false)
                  .timeout(const Duration(seconds: 3), onTimeout: () => null);
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

  /// Fetch all workouts from backend (to be used for video URL resolution)
  Future<Map<String, WorkoutData>> _fetchWorkoutsLibrary() async {
    if (_workoutsCache != null) return _workoutsCache!;
    if (_isFetchingWorkouts) {
      await Future.delayed(const Duration(milliseconds: 200));
      return _workoutsCache ?? {};
    }
    _isFetchingWorkouts = true;
    try {
      final response = await _dio.get(ApiConstants.workouts);
      if (response.statusCode == 200 && response.data is List) {
        final List<dynamic> list = response.data;
        final Map<String, WorkoutData> cache = {};
        for (var item in list) {
          final title = item['title'] as String?;
          if (title != null) {
            cache[title.toLowerCase()] = WorkoutData(
              title: title,
              videoUrl: item['videoUrl'] as String?,
              description: item['description'] as String?,
              targetMuscle: item['targetMuscle'] as String?,
            );
          }
        }
        _workoutsCache = cache;
        debugPrint('✅ Loaded ${cache.length} workouts into cache');
        return cache;
      } else {
        debugPrint('⚠️ Failed to fetch workouts: ${response.statusCode}');
        return {};
      }
    } catch (e) {
      debugPrint('⚠️ Error fetching workouts: $e');
      return {};
    } finally {
      _isFetchingWorkouts = false;
    }
  }

  /// Get video URL for a given exercise title (from backend cache or fallback)
  Future<String> getWorkoutVideoUrl(String title) async {
    try {
      final String jsonContent = await rootBundle.loadString('assets/workouts.json');
      final List<dynamic> jsonList = jsonDecode(jsonContent) as List<dynamic>;
      final key = title.toLowerCase().trim();
      for (var item in jsonList) {
        final itemTitle = (item['title'] as String?)?.toLowerCase().trim();
        if (itemTitle == key) {
          return item['videoUrl'] as String? ?? '';
        }
      }
    } catch (_) {}
    return '';
  }

  /// Get dynamic animated exercise GIF URL
  Future<String> getWorkoutGifUrl(String title) async {
    final sanitizedTitle = title.trim().toLowerCase();
    if (sanitizedTitle.isEmpty) return '';

    // 0. Try to load from assets/workouts.json first
    String videoUrl = '';
    try {
      final String jsonContent = await rootBundle.loadString('assets/workouts.json');
      final List<dynamic> jsonList = jsonDecode(jsonContent) as List<dynamic>;
      for (var item in jsonList) {
        final itemTitle = (item['title'] as String?)?.toLowerCase().trim();
        if (itemTitle == sanitizedTitle) {
          final gifUrl = item['gifUrl'] as String?;
          if (gifUrl != null && gifUrl.isNotEmpty) {
            return gifUrl;
          }
          videoUrl = item['videoUrl'] as String? ?? '';
        }
      }
    } catch (_) {}

    // 1. Try to fetch from ExerciseDB API via RapidAPI if a key is provided
    final apiKey = const String.fromEnvironment('RAPIDAPI_KEY');
    if (apiKey.isNotEmpty && apiKey != 'MOCK_KEY') {
      try {
        final encodedName = Uri.encodeComponent(sanitizedTitle);
        final response = await _dio.get(
          'https://exercisedb.p.rapidapi.com/exercises/name/$encodedName',
          options: Options(
            headers: {
              'x-rapidapi-key': apiKey,
              'x-rapidapi-host': 'exercisedb.p.rapidapi.com',
            },
          ),
        );
        if (response.statusCode == 200 && response.data is List && (response.data as List).isNotEmpty) {
          final first = response.data[0];
          final gifUrl = first['gifUrl'] as String?;
          if (gifUrl != null && gifUrl.isNotEmpty) {
            debugPrint('✅ Resolved $title GIF via ExerciseDB API: $gifUrl');
            return gifUrl;
          }
        }
      } catch (e) {
        debugPrint('⚠️ ExerciseDB API fetch failed for $title: $e. Falling back to dynamic links...');
      }
    }

    // 2. Try converting videoUrl to YouTube WebP/GIF stream
    if (videoUrl.isNotEmpty) {
      try {
        final uri = Uri.tryParse(videoUrl);
        if (uri != null) {
          String? videoId;
          if (videoUrl.contains('youtu.be/')) {
            videoId = videoUrl.split('youtu.be/').last.split('?').first;
          } else if (videoUrl.contains('v=')) {
            videoId = uri.queryParameters['v'];
          } else if (videoUrl.contains('shorts/')) {
            videoId = videoUrl.split('shorts/').last.split('?').first;
          } else if (videoUrl.contains('embed/')) {
            videoId = videoUrl.split('embed/').last.split('?').first;
          }

          if (videoId != null && videoId.isNotEmpty) {
            return 'https://i.ytimg.com/an_webp/$videoId/mqdefault_6s.webp';
          }
        }
      } catch (_) {}
    }

    // 3. Dynamic direct GIF link fallback
    final formattedName = sanitizedTitle
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '-');

    final customMapping = {
      'barbell bench press': 'https://media.giphy.com/media/v1.Y2lkPTc5MGI3NjExM3hpeDRuM3V4M3V4M3V4M3V4M3V4M3V4M3V4M3V4M3V4M3V4/3o7TKo7MuTj6yGjZy8/giphy.gif',
      'push-ups': 'https://media.giphy.com/media/v1.Y2lkPTc5MGI3NjExM3hpeDRuM3V4M3V4M3V4M3V4M3V4M3V4M3V4M3V4M3V4M3V4/3o7TKo7MuTj6yGjZy8/giphy.gif',
      'bodyweight squat': 'https://media.giphy.com/media/v1.Y2lkPTc5MGI3NjExM3hpeDRuM3V4M3V4M3V4M3V4M3V4M3V4M3V4M3V4M3V4M3V4/3o7TKo7MuTj6yGjZy8/giphy.gif',
    };

    if (customMapping.containsKey(sanitizedTitle)) {
      return customMapping[sanitizedTitle]!;
    }

    return 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/$formattedName/images/0.gif';
  }

  /// Helper to get full workout object by title
  Future<WorkoutData?> getWorkoutByTitle(String title) async {
    final workouts = await _fetchWorkoutsLibrary();
    final key = title.toLowerCase();
    if (workouts.containsKey(key)) {
      return workouts[key];
    }
    return null;
  }

  /// Personalized AI Workout Planner (POST /api/ai-workout)
  Future<AiWorkoutResponse> generateAiWorkout(AiWorkoutRequest request) async {
    try {
      final response = await _dio.post(
        ApiConstants.aiWorkout,
        data: request.toJson(),
      );

      if (response.statusCode == 200 && response.data != null) {
        return AiWorkoutResponse.fromJson(
          response.data as Map<String, dynamic>,
        );
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
      debugPrint(
        'Error generating workout: $e. Falling back to improved local AI simulator.',
      );
      return _generateImprovedSimulatedWorkoutResponse(request);
    }
  }

  /// Bilingual RAG AI Coach Chat Stream (POST /api/chat)
  Stream<String> streamChat(
    List<ChatMessageModel> messages, {
    Map<String, dynamic>? healthMetrics,
    Map<String, dynamic>? activeSessionLogs,
  }) async* {
    final buf = StringBuffer();
    buf.writeln('You are an elite, bilingual (English/Arabic) personal fitness coach.');
    buf.writeln('Respond ONLY in the same language the user writes in.');
    buf.writeln('Keep answers concise but action-oriented.');

    if (healthMetrics != null) {
      buf.writeln('\n## User Profile');
      buf.writeln('- Weight: ${healthMetrics['weight'] ?? 'unknown'} kg');
      buf.writeln('- Height: ${healthMetrics['height'] ?? 'unknown'} cm');
      buf.writeln('- Age: ${healthMetrics['age'] ?? 'unknown'}');
      buf.writeln('- Goals: ${(healthMetrics['goals'] as List?)?.join(', ') ?? 'General Fitness'}');
      buf.writeln('- Injuries/Limitations: ${healthMetrics['injuries'] ?? 'None'}');
      if (healthMetrics['bodyFat'] != null) buf.writeln('- Body Fat: ${healthMetrics['bodyFat']}%');
      if (healthMetrics['muscleMass'] != null) buf.writeln('- Muscle Mass: ${healthMetrics['muscleMass']} kg');
    }

    if (activeSessionLogs != null) {
      buf.writeln('\n## Recent Activity');
      buf.writeln('- Sessions completed: ${activeSessionLogs['completedSessions'] ?? 0}');
      buf.writeln('- Total volume lifted: ${activeSessionLogs['totalVolume'] ?? 0} kg');
      buf.writeln('- Average accuracy: ${activeSessionLogs['averageAccuracy'] ?? 0}%');
      buf.writeln('- Total training minutes: ${activeSessionLogs['totalMinutes'] ?? 0}');
    }

    buf.writeln('\nWhen proposing a workout plan, wrap the JSON in [PLAN_PROPOSAL]...[/PLAN_PROPOSAL] tags.');
    buf.writeln('Format: {"name":"...", "exercises":[{"workoutId":"...","title":"...","sets":[{"reps":N,"kg":N}],"order":N}]}');

    final systemMessage = {'role': 'system', 'content': buf.toString()};
    final messagesPayload = [
      systemMessage,
      ...messages.map((m) => {
        'role': m.role,
        'content': m.planProposal != null
            ? '${m.content}\n[PLAN_PROPOSAL]\n${jsonEncode(m.planProposal!.toJson())}\n[/PLAN_PROPOSAL]'
            : m.content,
      }),
    ];

    debugPrint('🌐 streamChat → POST ${ApiConstants.baseUrl}${ApiConstants.chat}');

    try {
      final response = await _dio.post<ResponseBody>(
        ApiConstants.chat,
        data: {'messages': messagesPayload},
        options: Options(
          responseType: ResponseType.stream,
          headers: {'Accept': 'text/event-stream', 'Content-Type': 'application/json'},
        ),
      );

      bool yieldedAny = false;
      final stream = response.data!.stream
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .timeout(const Duration(seconds: 30));

      await for (final line in stream) {
        if (line.startsWith('data: ')) {
          final data = line.substring(6).trim();
          if (data == '[DONE]') break;
          try {
            final decoded = jsonDecode(data);
            final content = (decoded is Map)
                ? (decoded['content'] ?? decoded['choices']?[0]?['delta']?['content'] ?? '')
                : data;
            if (content.toString().isNotEmpty) {
              yieldedAny = true;
              yield content.toString();
            }
          } catch (_) {
            yieldedAny = true;
            yield data;
          }
        } else if (line.startsWith('0:')) {
            final content = line.substring(2).trim();
            final unescaped = (content.startsWith('"') && content.endsWith('"')) 
              ? jsonDecode(content) as String : content;
            yieldedAny = true;
            yield unescaped;
        }
      }

      if (!yieldedAny) {
        debugPrint('⚠️ Vercel backend returned empty stream — trying Groq direct...');
        yield* _streamDirectGroq(
          messagesPayload,
          healthMetrics: healthMetrics,
          activeSessionLogs: activeSessionLogs,
          messages: messages,
        );
      }
    } catch (e) {
      debugPrint('❌ Vercel streamChat failed — trying Groq direct. Error: $e');
      yield* _streamDirectGroq(
        messagesPayload,
        healthMetrics: healthMetrics,
        activeSessionLogs: activeSessionLogs,
        messages: messages,
      );
    }
  }

  /// Direct Groq Cloud streaming — bypasses Vercel, uses compile-time GROQ_API_KEY.
  /// Falls through to local simulator if key is absent or Groq fails.
  Stream<String> _streamDirectGroq(
    List<Map<String, dynamic>> messagesPayload, {
    Map<String, dynamic>? healthMetrics,
    Map<String, dynamic>? activeSessionLogs,
    List<ChatMessageModel> messages = const [],
  }) async* {
    final groqKey = const String.fromEnvironment('GROQ_API_KEY');

    if (groqKey.isEmpty || groqKey == 'MOCK_MODE') {
      debugPrint('⚠️ No GROQ_API_KEY — using local RAG simulator.');
      yield* _streamImprovedSimulatedChatResponse(
        messages,
        healthMetrics: healthMetrics,
        activeSessionLogs: activeSessionLogs,
      );
      return;
    }

    try {
      final groqDio = Dio();
      final response = await groqDio.post<ResponseBody>(
        'https://api.groq.com/openai/v1/chat/completions',
        data: {
          'model': 'llama-3.3-70b-versatile',
          'messages': messagesPayload,
          'stream': true,
          'temperature': 0.7,
        },
        options: Options(
          responseType: ResponseType.stream,
          headers: {
            'Authorization': 'Bearer $groqKey',
            'Content-Type': 'application/json',
          },
        ),
      );

      bool yieldedAny = false;
      final stream = response.data!.stream
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      await for (final line in stream) {
        if (line.startsWith('data: ')) {
          final data = line.substring(6).trim();
          if (data == '[DONE]') break;
          try {
            final decoded = jsonDecode(data) as Map<String, dynamic>;
            final content = decoded['choices']?[0]?['delta']?['content'] as String?;
            if (content != null && content.isNotEmpty) {
              yieldedAny = true;
              yield content;
            }
          } catch (_) {}
        }
      }

      if (!yieldedAny) {
        yield* _streamImprovedSimulatedChatResponse(
          messages,
          healthMetrics: healthMetrics,
          activeSessionLogs: activeSessionLogs,
        );
      }
    } catch (e) {
      yield* _streamImprovedSimulatedChatResponse(
        messages,
        healthMetrics: healthMetrics,
        activeSessionLogs: activeSessionLogs,
      );
    }
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
    return 'https://www.youtube.com/watch?v=aclHkVaku9U';
  }

  // =========================================================================
  // IMPROVED SIMULATED WORKOUT GENERATOR (more precise, respects all parameters)
  // =========================================================================
  AiWorkoutResponse _generateImprovedSimulatedWorkoutResponse(
    AiWorkoutRequest request,
  ) {
    final lowerFocus = request.focus.toLowerCase();
    final experience = request.experience.toLowerCase();
    final frequency = request.frequency.toLowerCase();
    final hasInjuries = request.injuries.toLowerCase() != 'none';
    final injuryList = hasInjuries ? request.injuries.toLowerCase() : '';
    
    // Determine number of exercises based on frequency (more days = more variety)
    int exerciseCount = 4;
    if (frequency.contains('6')) {
      exerciseCount = 6;
    } else if (frequency.contains('5')) {
      exerciseCount = 5;
    } else if (frequency.contains('4')) {
      exerciseCount = 4;
    } else {
      exerciseCount = 3;
    }
    
    // Adjust sets/reps based on experience
    int setsBase = 3;
    int repsBase = 12;
    if (experience.contains('advanced')) {
      setsBase = 4;
      repsBase = 10;
    } else if (experience.contains('intermediate')) {
      setsBase = 3;
      repsBase = 12;
    } else {
      setsBase = 3;
      repsBase = 10;
    }
    
    // Exercise pool
    final allExercises = {
      'push': [
        {'name': 'Barbell Bench Press', 'target': 'chest', 'injuryRisk': 'shoulder'},
        {'name': 'Push-Up', 'target': 'chest', 'injuryRisk': 'wrist'},
        {'name': 'Overhead Dumbbell Tricep Extension', 'target': 'triceps', 'injuryRisk': 'elbow'},
        {'name': 'Incline Dumbbell Press', 'target': 'upper chest', 'injuryRisk': 'shoulder'},
        {'name': 'Diamond Push-Up', 'target': 'triceps', 'injuryRisk': 'wrist'},
        {'name': 'Cable Fly', 'target': 'chest', 'injuryRisk': 'shoulder'},
      ],
      'pull': [
        {'name': 'Pull-Up', 'target': 'back', 'injuryRisk': 'shoulder'},
        {'name': 'Lat Pulldown', 'target': 'back', 'injuryRisk': 'shoulder'},
        {'name': 'Seated Cable Row', 'target': 'back', 'injuryRisk': 'lower back'},
        {'name': 'Bent Over Row', 'target': 'back', 'injuryRisk': 'lower back'},
        {'name': 'Face Pull', 'target': 'rear delt', 'injuryRisk': 'shoulder'},
        {'name': 'Dumbbell Curl', 'target': 'biceps', 'injuryRisk': 'elbow'},
      ],
      'legs': [
        {'name': 'Bodyweight Squat', 'target': 'quadriceps', 'injuryRisk': 'knee'},
        {'name': 'Romanian Deadlift', 'target': 'hamstring', 'injuryRisk': 'lower back'},
        {'name': 'Walking Lunge', 'target': 'quadriceps', 'injuryRisk': 'knee'},
        {'name': 'Standing Calf Raise', 'target': 'calves', 'injuryRisk': 'ankle'},
        {'name': 'Leg Press', 'target': 'quadriceps', 'injuryRisk': 'knee'},
        {'name': 'Glute Bridge', 'target': 'glutes', 'injuryRisk': 'lower back'},
      ],
      'core': [
        {'name': 'Plank', 'target': 'abs', 'injuryRisk': 'lower back'},
        {'name': 'Russian Twist', 'target': 'obliques', 'injuryRisk': 'lower back'},
        {'name': 'Leg Raise', 'target': 'lower abs', 'injuryRisk': 'lower back'},
        {'name': 'Mountain Climber', 'target': 'abs', 'injuryRisk': 'wrist'},
        {'name': 'Bicycle Crunch', 'target': 'obliques', 'injuryRisk': 'neck'},
      ],
      'full_body': [
        {'name': 'Bodyweight Squat', 'target': 'legs', 'injuryRisk': 'knee'},
        {'name': 'Push-Up', 'target': 'chest', 'injuryRisk': 'wrist'},
        {'name': 'Pull-Up', 'target': 'back', 'injuryRisk': 'shoulder'},
        {'name': 'Plank', 'target': 'core', 'injuryRisk': 'lower back'},
        {'name': 'Lunge', 'target': 'legs', 'injuryRisk': 'knee'},
        {'name': 'Dumbbell Row', 'target': 'back', 'injuryRisk': 'shoulder'},
      ],
    };
    
    // Determine focus category
    List<Map<String, String>> availableExercises = [];
    if (lowerFocus.contains('push')) {
      availableExercises = List.from(allExercises['push']!);
    } else if (lowerFocus.contains('pull')) {
      availableExercises = List.from(allExercises['pull']!);
    } else if (lowerFocus.contains('leg') || lowerFocus.contains('lower')) {
      availableExercises = List.from(allExercises['legs']!);
    } else if (lowerFocus.contains('core') || lowerFocus.contains('ab')) {
      availableExercises = List.from(allExercises['core']!);
    } else {
      availableExercises = List.from(allExercises['full_body']!);
    }
    
    // Filter out exercises that conflict with injuries
    if (hasInjuries) {
      availableExercises = availableExercises.where((ex) {
        final risk = ex['injuryRisk']!;
        return !injuryList.contains(risk);
      }).toList();
    }
    
    // Shuffle and take needed count
    availableExercises.shuffle(Random());
    final selected = availableExercises.take(exerciseCount).toList();
    
    // If not enough exercises, add defaults
    if (selected.length < exerciseCount) {
      selected.addAll([
        {'name': 'Bodyweight Squat', 'target': 'legs', 'injuryRisk': 'knee'},
        {'name': 'Push-Up', 'target': 'chest', 'injuryRisk': 'wrist'},
      ].take(exerciseCount - selected.length));
    }
    
    final exercises = selected.map((ex) {
      final sets = setsBase + (Random().nextInt(2)); // +/-0 or 1
      final reps = repsBase + (Random().nextInt(4) - 2); // +/-2
      final weightKg = experience.contains('beginner') ? 'Bodyweight' : '${(repsBase * 2.5).round()} kg';
      return AiWorkoutExercise(
        name: ex['name']!,
        sets: sets.clamp(2, 5),
        reps: '${reps.clamp(6, 20)} reps',
        weightKg: weightKg,
        rest: setsBase > 3 ? '90s' : '60s',
        notes: 'Focus on form. ${hasInjuries ? 'Avoid aggravating $injuryList.' : ''}',
      );
    }).toList();
    
    final routineName = 'AI ${experience.toUpperCase()} ${request.focus} Plan';
    final summary = 'Personalized $experience level routine for ${request.focus}. Frequency: ${request.frequency}. Goal: ${request.goal}.';
    final List<String> warnings = hasInjuries ? ['Injury precaution: $injuryList. Modify range of motion.'] : [];
    
    return AiWorkoutResponse(
      routine: AiWorkoutRoutine(
        routineName: routineName,
        summary: summary,
        exercises: exercises,
        warnings: warnings,
      ),
    );
  }

  // =========================================================================
  // IMPROVED SIMULATED CHAT RESPONSE (varied, contextual, non-repetitive)
  // =========================================================================
  Stream<String> _streamImprovedSimulatedChatResponse(
    List<ChatMessageModel> messages, {
    Map<String, dynamic>? healthMetrics,
    Map<String, dynamic>? activeSessionLogs,
  }) async* {
    final userPrompt = messages.isNotEmpty ? messages.last.content : '';
    final lowerPrompt = userPrompt.toLowerCase();

    // ── Extract real profile values ────────────────────────────────────────
    final goals = (healthMetrics?['goals'] as List?)?.cast<String>() ?? ['General Fitness'];
    final injuries   = healthMetrics?['injuries'] as String? ?? 'None';
    final weightRaw  = healthMetrics?['weight'];
    final heightRaw  = healthMetrics?['height'];
    final ageRaw     = healthMetrics?['age'];
    final weight     = (weightRaw is num) ? weightRaw.toDouble() : double.tryParse(weightRaw?.toString() ?? '') ?? 75.0;
    final height     = (heightRaw is num) ? heightRaw.toDouble() : double.tryParse(heightRaw?.toString() ?? '') ?? 175.0;
    final age        = (ageRaw is num) ? ageRaw.toInt() : int.tryParse(ageRaw?.toString() ?? '') ?? 25;
    final completedSessions = activeSessionLogs?['completedSessions']?.toString() ?? '0';
    final totalVolume       = activeSessionLogs?['totalVolume']?.toString() ?? '0';
    final hasProfile = healthMetrics != null;

    final random = Random();
    final signOff = [' Stay strong! 💪', ' Keep pushing! 🔥', ' Train smart! 🧠', " I'm always here for you."];

    String responseText = '';

    // ── 1. CALORIE / MACRO / NUTRITION (highest priority) ─────────────────
    final isNutritionQuery = lowerPrompt.contains('calorie') || lowerPrompt.contains('calori') ||
        lowerPrompt.contains('macro') || lowerPrompt.contains('ماكرو') ||
        lowerPrompt.contains('كالوري') || lowerPrompt.contains('protein') ||
        lowerPrompt.contains('carb') || lowerPrompt.contains('fat') ||
        lowerPrompt.contains('tdee') || lowerPrompt.contains('bmr') ||
        lowerPrompt.contains('diet') || lowerPrompt.contains('eat') ||
        lowerPrompt.contains('food') || lowerPrompt.contains('nutrition') ||
        lowerPrompt.contains('meal') || lowerPrompt.contains('غذاء') ||
        lowerPrompt.contains('سعرات');

    // ── 2. MUSCLE FOCUS query ──────────────────────────────────────────────
    final isMuscleFocusQuery = lowerPrompt.contains('muscle') || lowerPrompt.contains('focus') ||
        lowerPrompt.contains('عضلة') || lowerPrompt.contains('أولوية') ||
        (lowerPrompt.contains('which') && (lowerPrompt.contains('train') || lowerPrompt.contains('work')));

    if (isNutritionQuery) {
      // ── Mifflin-St Jeor BMR ──────────────────────────────────────────────
      final bmr = (10 * weight) + (6.25 * height) - (5 * age) + 5; // male formula (conservative)
      final activityMultiplier = completedSessions == '0' ? 1.375 : 1.55; // lightly/moderately active
      final tdee = (bmr * activityMultiplier).round();

      // Adjust calories by goal
      int targetCalories = tdee;
      String goalContext = '';
      if (goals.any((g) => g.toLowerCase().contains('loss') || g.toLowerCase().contains('cut'))) {
        targetCalories = tdee - 400;
        goalContext = 'In a **calorie deficit** (-400 kcal) for fat loss.';
      } else if (goals.any((g) => g.toLowerCase().contains('gain') || g.toLowerCase().contains('muscle') || g.toLowerCase().contains('bulk'))) {
        targetCalories = tdee + 300;
        goalContext = 'In a **calorie surplus** (+300 kcal) for muscle gain.';
      } else {
        goalContext = 'At **maintenance** calories for body recomposition.';
      }

      // Macro split
      final proteinG  = (weight * 2.0).round();           // 2g per kg bodyweight
      final proteinKcal = proteinG * 4;
      final fatKcal   = (targetCalories * 0.25).round();
      final fatG      = (fatKcal / 9).round();
      final carbKcal  = targetCalories - proteinKcal - fatKcal;
      final carbG     = (carbKcal / 4).round();

      // Muscle priority based on goals
      String primaryMuscle = 'Compound movements (full body)';
      if (goals.any((g) => g.toLowerCase().contains('loss'))) {
        primaryMuscle = 'Large muscle groups (legs & back) — burns the most calories';
      } else if (goals.any((g) => g.toLowerCase().contains('posture'))) {
        primaryMuscle = 'Posterior chain: rear delts, rhomboids, glutes';
      } else if (goals.any((g) => g.toLowerCase().contains('endurance'))) {
        primaryMuscle = 'Cardiovascular base + lower body endurance (legs, core)';
      } else if (goals.any((g) => g.toLowerCase().contains('gain') || g.toLowerCase().contains('muscle'))) {
        primaryMuscle = 'Chest + back (largest muscle groups → fastest visible gains)';
      }

      responseText = hasProfile
          ? '📊 **Personalized Calorie & Macro Breakdown**\n\n'
              '**Your Stats:** ${weight.round()} kg • ${height.round()} cm • $age yrs\n'
              '**Goal:** ${goals.join(', ')}\n\n'
              '─────────────────────────\n'
              '🔥 **Estimated TDEE:** $tdee kcal/day\n'
              '🎯 **Target Calories:** $targetCalories kcal/day\n'
              '$goalContext\n\n'
              '**Macro Breakdown:**\n'
              '• 🥩 Protein: **${proteinG}g** ($proteinKcal kcal) — muscle preservation & recovery\n'
              '• 🍚 Carbs:   **${carbG}g** ($carbKcal kcal) — primary training fuel\n'
              '• 🥑 Fat:     **${fatG}g** ($fatKcal kcal) — hormones & joint health\n\n'
              '💡 **Muscle Priority for Weeks 1–2:**\n'
              '$primaryMuscle — train these 2–3× per week first.\n\n'
              '**Why?** Starting with large muscle groups maximises hormonal response (testosterone + GH) '
              'and establishes neural efficiency early in your program.${signOff[random.nextInt(signOff.length)]}'
          : 'To give you a precise calorie and macro breakdown, I need your profile data (weight, height, age, goals). '
              'Please complete your onboarding profile first, then I can calculate your exact TDEE and macros!';
    }

    // ── 3. MUSCLE FOCUS (standalone) ──────────────────────────────────────
    else if (isMuscleFocusQuery && !isNutritionQuery) {
      String muscleAdvice;
      if (goals.any((g) => g.toLowerCase().contains('loss'))) {
        muscleAdvice = '**Legs & Glutes** — they are your largest muscle groups and burn the most calories per session. '
            'Pair with back training to maintain posture under a calorie deficit.';
      } else if (goals.any((g) => g.toLowerCase().contains('posture'))) {
        muscleAdvice = '**Posterior chain** (rear delts, rhomboids, lower traps) — most people sit hunched forward, '
            'so pulling the shoulders back is the fastest posture fix. Add face pulls and rows every session.';
      } else if (goals.any((g) => g.toLowerCase().contains('gain') || g.toLowerCase().contains('muscle'))) {
        muscleAdvice = '**Chest + Back** simultaneously. These are the largest upper-body muscle groups. '
            'A push-pull pairing in weeks 1–2 builds the widest visible foundation and maximises hypertrophy signals.';
      } else {
        muscleAdvice = '**Core + Legs** — for general fitness, a strong core stabilises every other movement '
            'and strong legs drive your metabolism. Start here for the first two weeks.';
      }
      responseText = '🎯 **Muscle Focus — Weeks 1–2**\n\n'
          'Based on your goals (${goals.join(', ')}), prioritise:\n\n'
          '$muscleAdvice\n\n'
          'After 2 weeks your nervous system will be primed and you can expand to accessory work.${signOff[random.nextInt(signOff.length)]}';
    }

    // ── 4. WORKOUT PLAN ────────────────────────────────────────────────────
    else if (lowerPrompt.contains('plan') || lowerPrompt.contains('routine') ||
        lowerPrompt.contains('workout') || lowerPrompt.contains('schedule') ||
        lowerPrompt.contains('generate') || lowerPrompt.contains('create') ||
        lowerPrompt.contains('خطة') || lowerPrompt.contains('برنامج')) {
      final focus = _detectFocus(lowerPrompt);
      final planName = 'AI Custom ${_capitalize(focus)} Workout';
      final exercises = _generateExercisesForFocus(focus, injuries, random);
      responseText = 'Based on your profile (weight: ${weight.round()} kg, goals: ${goals.join(', ')}), '
          "I've created a personalized ${_capitalize(focus)} routine for you.\n\n"
          '[PLAN_PROPOSAL]\n'
          '{\n'
          '  "name": "$planName",\n'
          '  "exercises": ${jsonEncode(exercises)}\n'
          '}\n'
          '[/PLAN_PROPOSAL]\n\n'
          'Tap the card above to save this routine.${signOff[random.nextInt(signOff.length)]}';
    }

    // ── 5. FORM / TECHNIQUE ────────────────────────────────────────────────
    else if (lowerPrompt.contains('form') || lowerPrompt.contains('technique') || lowerPrompt.contains('how to')) {
      final exercise = _extractExerciseName(lowerPrompt);
      responseText = exercise.isNotEmpty
          ? 'For proper **$exercise** form:\n'
              '• Controlled eccentric phase (2–3 sec down)\n'
              '• Full range of motion without locking joints\n'
              '• Brace your core throughout\n'
              '• Exhale during the exertion phase\n\n'
              'Would you like a video tutorial?${signOff[random.nextInt(signOff.length)]}'
          : 'Proper form prevents injury. Keep your spine neutral, engage your core, '
              'and move through a full but pain-free range of motion. Which exercise are you working on?';
    }

    // ── 6. INJURY / PAIN ──────────────────────────────────────────────────
    else if (lowerPrompt.contains('injury') || lowerPrompt.contains('pain') || lowerPrompt.contains('hurt')) {
      responseText = "I'm sorry to hear you're experiencing discomfort. "
          'Based on your profile, you have: **$injuries**. '
          'Please consult a medical professional before continuing. '
          'In the meantime, consider low-impact alternatives like swimming or stationary cycling. '
          'Would you like modified exercises for your condition?';
    }

    // ── 7. PROGRESS ───────────────────────────────────────────────────────
    else if (lowerPrompt.contains('progress') || lowerPrompt.contains('improve') || lowerPrompt.contains('result')) {
      responseText = "Great job! You've completed **$completedSessions** sessions "
          'with a total volume of **$totalVolume kg**. '
          'To accelerate progress, increase weights by 5% weekly or add one extra set. '
          'Consistency is key!${signOff[random.nextInt(signOff.length)]}';
    }

    // ── 8. MOTIVATION ─────────────────────────────────────────────────────
    else if (lowerPrompt.contains('motivation') || lowerPrompt.contains('tired') || lowerPrompt.contains('give up')) {
      final quotes = [
        "The only bad workout is the one that didn't happen.",
        "Your body can stand almost anything. It's your mind you have to convince.",
        "Don't limit your challenges. Challenge your limits.",
        'The pain you feel today will be the strength you feel tomorrow.',
      ];
      responseText = '${quotes[random.nextInt(quotes.length)]} '
          "You've already shown dedication by completing **$completedSessions sessions**. "
          "Take a rest day if needed — but don't quit!${signOff[random.nextInt(signOff.length)]}";
    }

    // ── 9. SLEEP / RECOVERY ───────────────────────────────────────────────
    else if (lowerPrompt.contains('sleep') || lowerPrompt.contains('recovery') || lowerPrompt.contains('rest')) {
      responseText = '😴 **Recovery is where gains happen.**\n\n'
          '• Aim for **7–9 hours** of quality sleep per night\n'
          '• Take at least **1 full rest day** per 3 training days\n'
          '• Post-workout: consume **${(weight * 0.4).round()}g protein** within 45 minutes\n'
          '• Stay hydrated: **${(weight * 35 / 1000).toStringAsFixed(1)}L water** daily\n\n'
          'Poor recovery is the #1 reason people plateau.${signOff[random.nextInt(signOff.length)]}';
    }

    // ── 10. GREETING ──────────────────────────────────────────────────────
    else if (RegExp(r'\b(hello|hi|hey|hiya|howdy|مرحبا|السلام)\b').hasMatch(lowerPrompt)) {
      final hour = DateTime.now().hour;
      final timeGreeting = hour < 12 ? 'Good morning' : hour < 18 ? 'Good afternoon' : 'Good evening';
      responseText = "$timeGreeting${hasProfile ? ', ${goals.isNotEmpty ? goals.first : 'athlete'} in training' : ''}! "
          "I'm your AI fitness coach. I have access to your full profile — ask me about:\n"
          '• 📊 Calorie & macro breakdown\n'
          '• 💪 Which muscles to prioritise\n'
          '• 🏋️ Custom workout routines\n'
          '• 🥗 Nutrition advice\n'
          '• 📈 Progress analysis\n\n'
          'What would you like to focus on today?';
    }

    // ── 11. DEFAULT: use profile data in response ──────────────────────────
    else {
      responseText = hasProfile
          ? 'I understand you\'re asking about: "${userPrompt.length > 60 ? '${userPrompt.substring(0, 60)}...' : userPrompt}"\n\n'
              'Based on your profile (**${weight.round()} kg, ${height.round()} cm**, goals: ${goals.join(', ')}), '
              'here\'s what I can help you with:\n'
              '• 📊 Type "calorie breakdown" → get your exact TDEE and macros\n'
              '• 💪 Type "which muscle to focus on" → get a priority plan for your goals\n'
              '• 🏋️ Type "create a plan" → generate a full workout routine\n'
              '• 📈 Type "my progress" → review your training stats\n\n'
              'What would you like to dive into?${signOff[random.nextInt(signOff.length)]}'
          : "I'm your AI fitness coach. Complete your profile first so I can give you personalized advice. "
              "You can ask me to generate a workout plan, check your form, track progress, or provide calorie & macro breakdowns.";
    }

    // ── Stream word-by-word (plan block atomically) ────────────────────────
    final planStart = responseText.indexOf('[PLAN_PROPOSAL]');
    final textPart = planStart != -1 ? responseText.substring(0, planStart).trimRight() : responseText;
    final planPart = planStart != -1 ? responseText.substring(planStart) : '';

    final words = textPart.split(' ');
    for (final word in words) {
      yield '$word ';
      await Future.delayed(Duration(milliseconds: 25 + random.nextInt(20)));
    }
    if (planPart.isNotEmpty) yield planPart;
  }
  
  // Helper methods for chat simulation
  String _detectFocus(String lowerPrompt) {
    if (lowerPrompt.contains('chest') || lowerPrompt.contains('push')) return 'push';
    if (lowerPrompt.contains('back') || lowerPrompt.contains('pull')) return 'pull';
    if (lowerPrompt.contains('leg') || lowerPrompt.contains('squat')) return 'legs';
    if (lowerPrompt.contains('core') || lowerPrompt.contains('ab')) return 'core';
    return 'full_body';
  }
  
  String _extractExerciseName(String lowerPrompt) {
    final known = ['squat', 'bench press', 'push-up', 'pull-up', 'deadlift', 'plank', 'lunge'];
    for (var ex in known) {
      if (lowerPrompt.contains(ex)) return ex;
    }
    return '';
  }
  
  String _capitalize(String s) => s.isEmpty ? '' : s[0].toUpperCase() + s.substring(1);
  
  List<Map<String, dynamic>> _generateExercisesForFocus(String focus, String injuries, Random random) {
    // Simplified exercise generation for chat proposals
    final List<Map<String, dynamic>> exercises = [];
    if (focus == 'push') {
      exercises.add({'workoutId': 'push_ups_002', 'title': 'Push-Up', 'sets': [{'reps': 12, 'kg': 0}], 'order': 0});
      exercises.add({'workoutId': 'bench_press_001', 'title': 'Barbell Bench Press', 'sets': [{'reps': 10, 'kg': 30}], 'order': 1});
    } else if (focus == 'pull') {
      exercises.add({'workoutId': 'pull_ups_004', 'title': 'Pull-Up', 'sets': [{'reps': 8, 'kg': 0}], 'order': 0});
      exercises.add({'workoutId': 'rows_006', 'title': 'Seated Row', 'sets': [{'reps': 12, 'kg': 25}], 'order': 1});
    } else if (focus == 'legs') {
      exercises.add({'workoutId': 'squats_003', 'title': 'Bodyweight Squat', 'sets': [{'reps': 15, 'kg': 0}], 'order': 0});
      exercises.add({'workoutId': 'lunges_008', 'title': 'Walking Lunge', 'sets': [{'reps': 12, 'kg': 0}], 'order': 1});
    } else {
      exercises.add({'workoutId': 'squats_003', 'title': 'Bodyweight Squat', 'sets': [{'reps': 12, 'kg': 0}], 'order': 0});
      exercises.add({'workoutId': 'push_ups_002', 'title': 'Push-Up', 'sets': [{'reps': 12, 'kg': 0}], 'order': 1});
      exercises.add({'workoutId': 'plank_005', 'title': 'Plank', 'sets': [{'reps': 1, 'kg': 0}], 'order': 2});
    }
    return exercises;
  }

  /// Fetch Chat History (GET /api/chat)
  Future<List<ChatMessageModel>> getChatHistory() async {
    try {
      final response = await _dio.get(ApiConstants.chat);

      if (response.statusCode == 200 && response.data != null) {
        final list = response.data as List? ?? [];
        return list
            .map(
              (item) => ChatMessageModel.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
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
    if (lowerPrompt.contains('lower') ||
        lowerPrompt.contains('quadriceps') ||
        lowerPrompt.contains('lower body')) {
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
    } else if (lowerPrompt.contains('upper') ||
        lowerPrompt.contains('chest') ||
        lowerPrompt.contains('push')) {
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
            'content':
                '''{
              "name": "$routineName",
              "exercises": ${StreamMappingHelper.flatJsonExercises(selectedExercises)}
            }''',
          },
        },
      ],
    };
  }
}

class StreamMappingHelper {
  static String flatJsonExercises(List<Map<String, dynamic>> list) {
    final buffer = StringBuffer('[');
    for (int i = 0; i < list.length; i++) {
      final item = list[i];
      final setsStr = (item['sets'] as List)
          .map((s) => '{"reps": ${s['reps']}, "kg": ${s['kg']}}')
          .join(', ');
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