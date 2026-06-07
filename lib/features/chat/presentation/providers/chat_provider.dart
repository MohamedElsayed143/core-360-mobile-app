import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../data/models/chat_message_model.dart';
import '../../../onboarding/presentation/providers/auth_provider.dart';
import '../../../workouts/presentation/providers/analytics_provider.dart';

class ChatState {
  final List<ChatMessageModel> messages;
  final bool isStreaming;
  final String? errorMessage;

  ChatState({
    required this.messages,
    this.isStreaming = false,
    this.errorMessage,
  });

  ChatState copyWith({
    List<ChatMessageModel>? messages,
    bool? isStreaming,
    String? errorMessage,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isStreaming: isStreaming ?? this.isStreaming,
      errorMessage: errorMessage,
    );
  }
}

class ChatNotifier extends Notifier<ChatState> {
  @override
  ChatState build() {
    Future.microtask(() => loadHistory());
    return ChatState(messages: []);
  }

  Future<void> loadHistory() async {
    try {
      final apiClient = ref.read(apiClientProvider);
      final history = await apiClient.getChatHistory();
      state = ChatState(messages: history);
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to load chat history: $e');
    }
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty || state.isStreaming) return;

    final userMsg = ChatMessageModel(
      id: 'user-${DateTime.now().millisecondsSinceEpoch}',
      role: 'user',
      content: text,
    );

    // Add user message and placeholder assistant streaming message
    final assistantMsgId = 'assistant-${DateTime.now().millisecondsSinceEpoch}';
    final assistantPlaceholder = ChatMessageModel(
      id: assistantMsgId,
      role: 'assistant',
      content: '',
      isStreaming: true,
    );

    state = state.copyWith(
      messages: [...state.messages, userMsg, assistantPlaceholder],
      isStreaming: true,
    );

    final apiClient = ref.read(apiClientProvider);
    final accumulatedBuffer = StringBuffer();

    // ── Extract real user context from Riverpod providers ──────────
    Map<String, dynamic>? healthMetrics;
    Map<String, dynamic>? activeSessionLogs;

    try {
      final authState = ref.read(authProvider);
      if (authState is AuthenticatedWithProfile) {
        final profile = authState.profile;
        healthMetrics = {
          'weight': profile.weight,
          'height': profile.height,
          'age': profile.age,
          'goals': profile.goals,
          'injuries': profile.injuries ?? 'None',
          if (profile.bodyFat != null) 'bodyFat': profile.bodyFat,
          if (profile.muscleMass != null) 'muscleMass': profile.muscleMass,
        };
      }

      final analytics = ref.read(analyticsProvider);
      activeSessionLogs = {
        'completedSessions': analytics.completedSessions,
        'totalVolume': analytics.totalVolume,
        'averageAccuracy': analytics.averageAccuracy,
        'totalMinutes': analytics.totalMinutes,
        'lookbackDays': analytics.lookbackDays,
      };
    } catch (e) {
      debugPrint('Failed to extract user context for RAG injection: $e');
    }

    try {
      // Guard: 10-second CONNECTION timeout only.
      // Once the first chunk arrives we let the stream run to completion
      // so long plan-proposal responses are never cut off mid-message.
      bool firstChunkReceived = false;

      final stream = apiClient.streamChat(
        state.messages.where((m) => m.id != assistantMsgId).toList(),
        healthMetrics: healthMetrics,
        activeSessionLogs: activeSessionLogs,
      );

      await for (final chunk in stream.timeout(
        const Duration(seconds: 10),
        onTimeout: (sink) {
          // Only close if we haven't seen any data yet (connection hung)
          if (!firstChunkReceived) {
            debugPrint('Backend chat: no response in 10s — closing stream and using fallback.');
            sink.close();
          }
          // If data is flowing, reset is not possible via onTimeout, but
          // simply not closing prevents the stream from being killed.
        },
      )) {
        firstChunkReceived = true;
        accumulatedBuffer.write(chunk);

        final updatedAssistantMsg = ChatMessageModel.fromStreamUpdate(
          id: assistantMsgId,
          role: 'assistant',
          accumulatedContent: accumulatedBuffer.toString(),
          isStreaming: true,
        );

        state = state.copyWith(
          messages: state.messages
              .map((m) => m.id == assistantMsgId ? updatedAssistantMsg : m)
              .toList(),
        );
      }
    } catch (e) {
      debugPrint('Error or timeout in backend chat stream: $e');
    }



    // Note: the fallback to the local simulated AI is now handled
    // internally inside ApiClient.streamChat — no secondary fallback needed here.


    // Mark streaming completed
    final finalAssistantMsg = ChatMessageModel.fromStreamUpdate(
      id: assistantMsgId,
      role: 'assistant',
      accumulatedContent: accumulatedBuffer.toString(),
      isStreaming: false,
    );

    state = state.copyWith(
      messages: state.messages.map((m) => m.id == assistantMsgId ? finalAssistantMsg : m).toList(),
      isStreaming: false,
    );
  }

  void clearChat() {
    state = ChatState(messages: []);
  }
}

final chatProvider = NotifierProvider<ChatNotifier, ChatState>(ChatNotifier.new);
