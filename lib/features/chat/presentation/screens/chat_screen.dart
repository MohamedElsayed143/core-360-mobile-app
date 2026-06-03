import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/network/api_client.dart';
import '../../../workouts/domain/entities/exercise.dart';
import '../../../workouts/domain/entities/routine.dart';
import '../../../workouts/domain/entities/routine_exercise.dart';
import '../../../workouts/domain/entities/set_config.dart';
import '../../../workouts/presentation/providers/workout_provider.dart';
import '../../data/models/chat_message_model.dart';
import '../../data/models/plan_proposal_model.dart';
import '../providers/chat_provider.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);
    final globalWorkoutsAsync = ref.watch(globalWorkoutsProvider);
    final globalWorkouts = globalWorkoutsAsync.value ?? [];

    // Trigger scrolling on updates
    ref.listen(chatProvider, (prev, next) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    });

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.darkBackground,
        elevation: 0,
        centerTitle: true,
        title: Column(
          children: [
            Text(
              'AI COACH',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                color: Colors.white,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppTheme.cyberCyan,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'BILINGUAL ACTIVE (EN/AR)',
                  style: GoogleFonts.outfit(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textMuted,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppTheme.textSub, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppTheme.textMuted),
            onPressed: () {
              ref.read(chatProvider.notifier).clearChat();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'CONVERSATION LOGS RESET.',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                  ),
                  backgroundColor: AppTheme.amethystPurple,
                ),
              );
            },
            tooltip: 'Clear Chat History',
          ),
        ],
      ),
      body: Stack(
        children: [
          // ─── AMBIENT BACKGROUND GLOWS ────────────────────────────────────
          Positioned(
            top: -50,
            left: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.cyberCyan.withValues(alpha: 0.03),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.cyberCyan.withValues(alpha: 0.02),
                    blurRadius: 100,
                    spreadRadius: 30,
                  )
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.amethystPurple.withValues(alpha: 0.04),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.amethystPurple.withValues(alpha: 0.02),
                    blurRadius: 120,
                    spreadRadius: 40,
                  )
                ],
              ),
            ),
          ),

          // ─── MAIN CHAT INTERFACE ─────────────────────────────────────────
          Column(
            children: [
              // Messages Ledger
              Expanded(
                child: chatState.messages.isEmpty
                    ? _buildWelcomeMessage()
                    : ListView.builder(
                        controller: _scrollController,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        itemCount: chatState.messages.length,
                        itemBuilder: (context, index) {
                          final message = chatState.messages[index];
                          return _buildMessageBubble(message, globalWorkouts);
                        },
                      ),
              ),

              // Chat Send Panel
              _buildInputPanel(chatState),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeMessage() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.darkSurface,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.cyberCyan.withValues(alpha: 0.2), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.cyberCyan.withValues(alpha: 0.03),
                    blurRadius: 30,
                  )
                ],
              ),
              child: ShaderMask(
                shaderCallback: (bounds) => AppTheme.primaryGradient.createShader(bounds),
                child: const Icon(
                  Icons.auto_awesome,
                  size: 48,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'AI FITNESS COACH',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'How can I help you optimize your athletic potential today?\nFeel free to ask in English or Arabic.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: AppTheme.textSub,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            _buildSamplePromptGrid(),
          ],
        ),
      ),
    );
  }

  Widget _buildSamplePromptGrid() {
    final prompts = [
      "Suggest a plan with plank and pushups.",
      "اقترح خطة تدريبية لتقوية عضلات الصدر.",
      "How should I adjust routines for shoulder pain?",
      "أحتاج تمارين هوائية لحرق الدهون.",
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: prompts.map((prompt) {
        return GestureDetector(
          onTap: () {
            _messageController.text = prompt;
            _sendMessage();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.darkSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.cardBorderColor, width: 1.0),
            ),
            child: Text(
              prompt,
              style: GoogleFonts.outfit(
                fontSize: 11,
                color: AppTheme.cyberCyan.withValues(alpha: 0.8),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMessageBubble(ChatMessageModel message, List<Exercise> globalWorkouts) {
    final isUser = message.role == 'user';
    final hasProposal = message.planProposal != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser) ...[
                Container(
                  width: 32,
                  height: 32,
                  margin: const EdgeInsets.only(right: 8, top: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.darkSurface,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.cyberCyan.withValues(alpha: 0.3), width: 1.0),
                  ),
                  child: const Center(
                    child: Icon(Icons.bolt, color: AppTheme.cyberCyan, size: 16),
                  ),
                ),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isUser ? AppTheme.darkSurface : AppTheme.darkSurface.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(isUser ? 20 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 20),
                    ),
                    border: Border.all(
                      color: isUser ? AppTheme.cyberCyan.withValues(alpha: 0.3) : AppTheme.cardBorderColor,
                      width: 1.2,
                    ),
                  ),
                  child: message.isStreaming && message.content.isEmpty
                      ? SizedBox(
                          width: 24,
                          height: 12,
                          child: LinearProgressIndicator(
                            color: AppTheme.cyberCyan.withValues(alpha: 0.5),
                            backgroundColor: Colors.transparent,
                            minHeight: 2,
                          ),
                        )
                      : Text(
                          message.content,
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.95),
                            height: 1.4,
                          ),
                        ),
                ),
              ),
            ],
          ),
          if (message.thinking != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 40),
              child: () {
                bool expanded = false;
                return StatefulBuilder(
                  builder: (context, setBubbleState) {
                    return Container(
                      decoration: BoxDecoration(
                        color: AppTheme.darkSurface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.cardBorderColor, width: 1.0),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          InkWell(
                            onTap: () => setBubbleState(() => expanded = !expanded),
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.psychology_outlined, color: AppTheme.cyberCyan, size: 18),
                                      const SizedBox(width: 8),
                                      Text(
                                        'AI Coach Thought Process',
                                        style: GoogleFonts.outfit(
                                          fontSize: 12,
                                          color: AppTheme.textSub,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Icon(
                                    expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                    color: AppTheme.textMuted,
                                    size: 18,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (expanded)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                              child: Text(
                                message.thinking!,
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  color: AppTheme.textMuted,
                                  height: 1.4,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  }
                );
              }(),
            ),
          ],
          if (hasProposal) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(left: 40),
              child: _buildPlanProposalCard(message.planProposal!, globalWorkouts),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlanProposalCard(PlanProposalModel proposal, List<Exercise> globalWorkouts) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.cyberCyan.withValues(alpha: 0.4), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppTheme.cyberCyan.withValues(alpha: 0.04),
            blurRadius: 20,
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ShaderMask(
                shaderCallback: (bounds) => AppTheme.primaryGradient.createShader(bounds),
                child: const Icon(Icons.auto_awesome_outlined, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'INTERACTIVE PLAN PROPOSAL',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: proposal.exercises.length,
            separatorBuilder: (context, index) => const Divider(color: AppTheme.cardBorderColor, height: 16),
            itemBuilder: (context, idx) {
              final ex = proposal.exercises[idx];
              final isUpcoming = ex.status == 'upcoming';
              return Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isUpcoming ? AppTheme.glassFillColor : AppTheme.cyberCyan.withValues(alpha: 0.08),
                      border: Border.all(
                        color: isUpcoming ? AppTheme.cardBorderColor : AppTheme.cyberCyan.withValues(alpha: 0.5),
                        width: 1.0,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        isUpcoming ? Icons.circle_outlined : Icons.check,
                        color: isUpcoming ? AppTheme.textMuted : AppTheme.cyberCyan,
                        size: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ex.name,
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          ex.setsDisplay,
                          style: GoogleFonts.outfit(
                            color: AppTheme.textMuted,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isUpcoming ? AppTheme.glassFillColor : AppTheme.cyberCyan.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      ex.status.toUpperCase(),
                      style: GoogleFonts.outfit(
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        color: isUpcoming ? AppTheme.textSub : AppTheme.cyberCyan,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => _importProposal(proposal, globalWorkouts),
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
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                height: 48,
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_box_outlined, color: Colors.black, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'IMPORT TO ROUTINES',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
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

  Future<void> _importProposal(PlanProposalModel proposal, List<Exercise> globalWorkouts) async {
    try {
      final routine = Routine(
        id: '',
        userId: '', // WorkoutNotifier handles injection of active UID
        name: 'AI Coach Plan Proposal',
        exercises: proposal.exercises.map((e) {
          final matchedEx = globalWorkouts.firstWhere(
            (w) => w.title.toLowerCase().contains(e.name.toLowerCase()) ||
                   e.name.toLowerCase().contains(w.title.toLowerCase()),
            orElse: () => Exercise(
              id: 'dynamic_${e.key}',
              title: e.name,
              description: '',
              targetMuscle: 'full_body',
              thumbnailUrl: '',
              videoUrl: ApiClient.resolveWorkoutVideoUrl(e.name),
              aiSupported: false,
            ),
          );

          int numSets = 3;
          int reps = 10;

          try {
            final parsedSets = jsonDecode(e.sets) as List;
            if (parsedSets.isNotEmpty) {
              numSets = parsedSets.length;
              if (parsedSets[0] is Map) {
                reps = (parsedSets[0]['reps'] ?? 10) as int;
              }
            }
          } catch (_) {
            final setMatch = RegExp(r'(\d+)x').firstMatch(e.sets);
            if (setMatch != null) {
              numSets = int.tryParse(setMatch.group(1)!) ?? 3;
              final repsMatch = RegExp(r'x(\d+)').firstMatch(e.sets);
              reps = repsMatch != null ? int.tryParse(repsMatch.group(1)!) ?? 10 : 10;
            } else {
              final setMatch2 = RegExp(r'(\d+)').firstMatch(e.sets);
              if (setMatch2 != null) {
                numSets = int.tryParse(setMatch2.group(1)!) ?? 3;
              }
            }
          }

          return RoutineExercise(
            workoutId: matchedEx.id,
            title: matchedEx.title,
            targetMuscle: matchedEx.targetMuscle,
            sets: List.generate(numSets, (_) => SetConfig(reps: reps, weight: 0.0)),
            order: proposal.exercises.indexOf(e),
          );
        }).toList(),
        isAiGenerated: true,
        createdAt: DateTime.now(),
      );

      await ref.read(userRoutinesProvider.notifier).saveRoutine(routine);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'PLAN SUCCESSFULY IMPORTED TO ROUTINE LIBRARY.',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
            backgroundColor: AppTheme.cyberCyan,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'IMPORT FAILED: $e',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Widget _buildInputPanel(ChatState chatState) {
    return Container(
      padding: const EdgeInsets.only(left: 20, right: 20, bottom: 24, top: 12),
      decoration: BoxDecoration(
        color: AppTheme.darkBackground,
        border: const Border(
          top: BorderSide(
            color: AppTheme.cardBorderColor,
            width: 1.0,
          ),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.darkSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.cardBorderColor, width: 1.2),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        textCapitalization: TextCapitalization.sentences,
                        style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: chatState.isStreaming 
                              ? 'Coach is compiling response...' 
                              : 'Ask AI Coach anything...',
                          hintStyle: GoogleFonts.outfit(color: AppTheme.textMuted, fontSize: 13),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 14),
                          filled: false,
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: chatState.isStreaming ? null : _sendMessage,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: chatState.isStreaming ? null : AppTheme.primaryGradient,
                  color: chatState.isStreaming ? AppTheme.cardBorderColor : null,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    if (!chatState.isStreaming)
                      BoxShadow(
                        color: AppTheme.cyberCyan.withValues(alpha: 0.2),
                        blurRadius: 10,
                        spreadRadius: 1,
                      )
                  ],
                ),
                child: Center(
                  child: chatState.isStreaming
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: AppTheme.textSub,
                            strokeWidth: 2.0,
                          ),
                        )
                      : const Icon(
                          Icons.send_rounded,
                          color: Colors.black,
                          size: 20,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();
    ref.read(chatProvider.notifier).sendMessage(text);
  }
}
