import 'dart:convert';
import 'plan_proposal_model.dart';

class ChatMessageModel {
  final String id;
  final String role;
  final String content;
  final String? thinking;
  final bool isStreaming;
  final PlanProposalModel? planProposal;

  ChatMessageModel({
    required this.id,
    required this.role,
    required this.content,
    this.thinking,
    this.isStreaming = false,
    this.planProposal,
  });

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    final rawContent = json['content'] as String? ?? '';
    final parsedThinking = _parseThinking(rawContent);
    final parsedProposal = _parseContentForProposal(parsedThinking.cleanContent);
    return ChatMessageModel(
      id: json['id'] as String? ?? json['_id'] as String? ?? '',
      role: json['role'] as String? ?? 'user',
      content: parsedProposal.cleanContent,
      thinking: parsedThinking.thinking,
      planProposal: parsedProposal.proposal,
      isStreaming: false,
    );
  }

  Map<String, dynamic> toJson() {
    final fullContent = thinking != null ? '<think>$thinking</think>\n$content' : content;
    return {
      'id': id,
      'role': role,
      'content': planProposal != null 
          ? '$fullContent\n[PLAN_PROPOSAL]\n${jsonEncode(planProposal!.toJson())}\n[/PLAN_PROPOSAL]' 
          : fullContent,
    };
  }

  ChatMessageModel copyWith({
    String? id,
    String? role,
    String? content,
    String? thinking,
    bool? isStreaming,
    PlanProposalModel? planProposal,
  }) {
    return ChatMessageModel(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      thinking: thinking ?? this.thinking,
      isStreaming: isStreaming ?? this.isStreaming,
      planProposal: planProposal ?? this.planProposal,
    );
  }

  static _ParsedThinking _parseThinking(String text) {
    final thinkStart = text.indexOf('<think>');
    if (thinkStart != -1) {
      final thinkEnd = text.indexOf('</think>');
      if (thinkEnd != -1) {
        final thinking = text.substring(thinkStart + 7, thinkEnd).trim();
        final clean = (text.substring(0, thinkStart) + text.substring(thinkEnd + 8)).trim();
        return _ParsedThinking(clean, thinking.isNotEmpty ? thinking : null);
      } else {
        final thinking = text.substring(thinkStart + 7).trim();
        final clean = text.substring(0, thinkStart).trim();
        return _ParsedThinking(clean, thinking.isNotEmpty ? thinking : null);
      }
    }
    return _ParsedThinking(text, null);
  }

  static _ParsedProposal _parseContentForProposal(String text) {
    final regExp = RegExp(r'\[PLAN_PROPOSAL\](.*?)\[/PLAN_PROPOSAL\]', dotAll: true);
    final match = regExp.firstMatch(text);
    if (match != null) {
      final jsonStr = match.group(1)?.trim() ?? '';
      try {
        final parsedJson = jsonDecode(jsonStr) as Map<String, dynamic>;
        final proposal = PlanProposalModel.fromJson(parsedJson);
        final clean = text.replaceAll(regExp, '').trim();
        return _ParsedProposal(clean, proposal);
      } catch (e) {
        return _ParsedProposal(text, null);
      }
    }
    return _ParsedProposal(text, null);
  }

  static ChatMessageModel fromStreamUpdate({
    required String id,
    required String role,
    required String accumulatedContent,
    required bool isStreaming,
  }) {
    final parsedThinking = _parseThinking(accumulatedContent);
    final parsedProposal = _parseContentForProposal(parsedThinking.cleanContent);
    return ChatMessageModel(
      id: id,
      role: role,
      content: parsedProposal.cleanContent,
      thinking: parsedThinking.thinking,
      planProposal: parsedProposal.proposal,
      isStreaming: isStreaming,
    );
  }
}

class _ParsedThinking {
  final String cleanContent;
  final String? thinking;
  _ParsedThinking(this.cleanContent, this.thinking);
}

class _ParsedProposal {
  final String cleanContent;
  final PlanProposalModel? proposal;
  _ParsedProposal(this.cleanContent, this.proposal);
}
