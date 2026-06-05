import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/routine.dart';
import '../providers/share_provider.dart';

class ShareImportDialog extends ConsumerStatefulWidget {
  final Routine? routineToShare;
  const ShareImportDialog({super.key, this.routineToShare});

  @override
  ConsumerState<ShareImportDialog> createState() => _ShareImportDialogState();
}

class _ShareImportDialogState extends ConsumerState<ShareImportDialog> {
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _importNameController = TextEditingController();
  Routine? _previewRoutine;
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    if (widget.routineToShare != null) {
      // Automatically generate share code on open in share mode
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(shareProvider.notifier).generateShareCode(widget.routineToShare!);
      });
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _importNameController.dispose();
    super.dispose();
  }

  Future<void> _lookupCode() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) return;

    final routine = await ref.read(shareProvider.notifier).lookupShareCode(code);
    if (routine != null) {
      setState(() {
        _previewRoutine = routine;
        _importNameController.text = '${routine.name} IMPORT';
        _hasSearched = true;
      });
    } else {
      setState(() {
        _previewRoutine = null;
        _hasSearched = true;
      });
    }
  }

  Future<void> _import() async {
    if (_previewRoutine == null) return;
    
    try {
      await ref.read(shareProvider.notifier).importRoutine(
        _previewRoutine!,
        _importNameController.text.trim(),
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'ROUTINE IMPORTED SUCCESSFULLY.',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
            backgroundColor: AppTheme.cyberCyan,
          ),
        );
        Navigator.pop(context);
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

  @override
  Widget build(BuildContext context) {
    final shareState = ref.watch(shareProvider);
    final isShareMode = widget.routineToShare != null;

    return Dialog(
      backgroundColor: AppTheme.darkSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: AppTheme.cardBorderColor, width: 1.5),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isShareMode ? 'SHARE ROUTINE' : 'IMPORT ROUTINE',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppTheme.textSub, size: 20),
                    onPressed: () {
                      ref.read(shareProvider.notifier).clearState();
                      Navigator.pop(context);
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Divider(color: AppTheme.cardBorderColor),
              const SizedBox(height: 16),

              // Content depending on mode
              if (isShareMode)
                _buildShareContent(shareState)
              else
                _buildImportContent(shareState),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShareContent(ShareState state) {
    if (state.isLoading) {
      return const SizedBox(
        height: 120,
        child: Center(
          child: CircularProgressIndicator(color: AppTheme.cyberCyan),
        ),
      );
    }

    if (state.errorMessage != null) {
      return Column(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
          const SizedBox(height: 12),
          Text(
            state.errorMessage!,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(color: AppTheme.textSub),
          ),
        ],
      );
    }

    final code = state.shareCode ?? '';

    return Column(
      children: [
        Text(
          'YOUR PEER SHARE CODE IS LIVE',
          style: GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: AppTheme.cyberCyan,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 16),
        
        // Share code box
        GestureDetector(
          onTap: () {
            Clipboard.setData(ClipboardData(text: code));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'CODE COPIED TO CLIPBOARD.',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                ),
                backgroundColor: AppTheme.cyberCyan,
                duration: const Duration(seconds: 1),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.cyberCyan.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  code,
                  style: GoogleFonts.outfit(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 2.0,
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.copy, color: AppTheme.cyberCyan, size: 20),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Tap to copy. This code will automatically expire in 7 days.',
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            fontSize: 12,
            color: AppTheme.textSub,
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () {
            ref.read(shareProvider.notifier).clearState();
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.darkSurface,
            foregroundColor: Colors.white,
            side: const BorderSide(color: AppTheme.cardBorderColor),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            minimumSize: const Size(double.infinity, 48),
          ),
          child: Text(
            'DONE',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildImportContent(ShareState state) {
    if (state.isLoading) {
      return const SizedBox(
        height: 150,
        child: Center(
          child: CircularProgressIndicator(color: AppTheme.cyberCyan),
        ),
      );
    }

    if (_previewRoutine == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _codeController,
            style: GoogleFonts.outfit(color: Colors.white),
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'ENTER 8-CHARACTER CODE',
              hintText: 'E.G., CORE7X9A',
            ),
          ),
          if (_hasSearched && state.errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              state.errorMessage!,
              style: GoogleFonts.outfit(color: Colors.redAccent, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _lookupCode,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Ink(
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Container(
                height: 48,
                alignment: Alignment.center,
                child: Text(
                  'LOOKUP ROUTINE',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Displays import preview
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'ROUTINE FOUND: ${_previewRoutine!.name}',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: AppTheme.cyberCyan,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _importNameController,
          style: GoogleFonts.outfit(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'CUSTOM IMPORT NAME',
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'EXERCISES TO IMPORT:',
          style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textSub),
        ),
        const SizedBox(height: 8),
        Container(
          constraints: const BoxConstraints(maxHeight: 180),
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.cardBorderColor),
          ),
          child: ListView.builder(
            shrinkWrap: true,
            physics: const BouncingScrollPhysics(),
            itemCount: _previewRoutine!.exercises.length,
            itemBuilder: (context, idx) {
              final ex = _previewRoutine!.exercises[idx];
              return ListTile(
                dense: true,
                title: Text(
                  ex.title,
                  style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '${ex.sets.length} Sets • ${ex.targetMuscle.toUpperCase()}',
                  style: GoogleFonts.outfit(color: AppTheme.textSub, fontSize: 11),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  setState(() {
                    _previewRoutine = null;
                    _hasSearched = false;
                  });
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppTheme.cardBorderColor),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  'BACK',
                  style: GoogleFonts.outfit(color: AppTheme.textSub, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _import,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Container(
                    height: 48,
                    alignment: Alignment.center,
                    child: Text(
                      'IMPORT NOW',
                      style: GoogleFonts.outfit(color: Colors.black, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
