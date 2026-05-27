import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../data/models/chat_message_model.dart';

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

    bool yieldedAny = false;

    try {
      // Stream chunks from backend SSE endpoint with a 6-second timeout
      final stream = apiClient.streamChat(
        state.messages.where((m) => m.id != assistantMsgId).toList(),
      ).timeout(const Duration(seconds: 6));

      await for (final chunk in stream) {
        yieldedAny = true;
        accumulatedBuffer.write(chunk);
        
        // Dynamic parsed model mapping with regex handling
        final updatedAssistantMsg = ChatMessageModel.fromStreamUpdate(
          id: assistantMsgId,
          role: 'assistant',
          accumulatedContent: accumulatedBuffer.toString(),
          isStreaming: true,
        );

        // Update list inline to trigger real-time micro-animation changes
        state = state.copyWith(
          messages: state.messages.map((m) => m.id == assistantMsgId ? updatedAssistantMsg : m).toList(),
        );
      }
    } catch (e) {
      debugPrint('Error or timeout in backend chat stream: $e');
    }

    // Fallback if no content was yielded from the backend
    if (!yieldedAny) {
      debugPrint('No content yielded from backend. Falling back to local RAG AI Coach.');
      try {
        final simulatedStream = apiClient.streamSimulatedChatResponse(
          state.messages.where((m) => m.id != assistantMsgId).toList(),
        );
        await for (final chunk in simulatedStream) {
          accumulatedBuffer.write(chunk);

          final updatedAssistantMsg = ChatMessageModel.fromStreamUpdate(
            id: assistantMsgId,
            role: 'assistant',
            accumulatedContent: accumulatedBuffer.toString(),
            isStreaming: true,
          );

          state = state.copyWith(
            messages: state.messages.map((m) => m.id == assistantMsgId ? updatedAssistantMsg : m).toList(),
          );
        }
      } catch (simError) {
        debugPrint('Error in simulated chat stream: $simError');
      }
    }

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
