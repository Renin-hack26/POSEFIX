import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exception.dart';
import '../../core/theme/app_theme.dart';
import '../../core/veda/veda_service.dart';
import '../../domain/entities/chat_message.dart';
import '../shared/app_back_button.dart';
import '../shared/grid_background.dart';

/// VEDA chat screen — real GROQ-backed conversation.
///
/// Flow:
/// - User sends message → instantly shows user bubble + typing indicator.
/// - Background: calls VedaService.sendMessage (GROQ with context).
/// - On success: replace typing indicator with assistant bubble.
/// - On error (missing key, HTTP error, timeout): show error bubble with Retry.
/// - No canned/fake replies; conversation persists via VedaRepository.
class VedaChatScreen extends ConsumerStatefulWidget {
  const VedaChatScreen({super.key});

  @override
  ConsumerState<VedaChatScreen> createState() => _VedaChatScreenState();
}

class _VedaChatScreenState extends ConsumerState<VedaChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<_ChatEntry> _entries = [];

  // Starter suggestion chips (send real messages when tapped).
  static const _suggestions = [
    _Suggestion(icon: Icons.fitness_center, label: 'Adjust today\'s plan'),
    _Suggestion(icon: Icons.analytics, label: 'Explain my report'),
    _Suggestion(icon: Icons.restaurant, label: 'High-protein meals'),
    _Suggestion(icon: Icons.nightlight_round, label: 'Sleep & recovery'),
  ];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final service = ref.read(vedaServiceProvider);
    final history = await service.history();
    if (!mounted) return;
    setState(() {
      _entries.clear();
      for (final msg in history) {
        _entries.add(_ChatEntry.message(msg));
      }
    });
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final service = ref.read(vedaServiceProvider);
    final userEntry = _ChatEntry.message(
      ChatMessage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        role: ChatRole.user,
        text: text,
        createdAt: DateTime.now(),
      ),
    );

    setState(() {
      _entries.add(userEntry);
      _entries.add(_ChatEntry.typing());
      _controller.clear();
    });
    _scrollToEnd();

    try {
      final assistantMsg = await service.sendMessage(text).timeout(
        const Duration(seconds: 35),
        onTimeout: () => throw const VedaUnavailableException(
            'VEDA took too long to answer — please try again'),
      );
      if (!mounted) return;
      setState(() {
        // Replace typing indicator with assistant message
        _entries.removeLast(); // remove typing
        _entries.add(_ChatEntry.message(assistantMsg));
      });
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() {
        _entries.removeLast(); // remove typing
        _entries.add(_ChatEntry.error(e.message, text));
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _entries.removeLast(); // remove typing
        _entries.add(_ChatEntry.error(
          "VEDA can't reach its assistant right now — check your connection",
          text,
        ));
      });
    }
    _scrollToEnd();
  }

  void _retry(String originalPrompt) {
    _controller.text = originalPrompt;
    _send();
  }

  void _useSuggestion(String label) {
    _controller.text = label;
    _send();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      body: GridBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 6, 18, 10),
                child: Row(
                  children: [
                    const AppBackButton(),
                    const SizedBox(width: 11),
                    _orb(),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'VEDA',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: p.ink,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            'AI coach · knows your plan & reports',
                            style: TextStyle(fontSize: 11.5, color: p.ink3),
                          ),
                        ],
                      ),
                    ),
                    const _IconBox(Icons.more_horiz),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(18, 6, 18, 12),
                  children: [
                    if (_entries.isEmpty) _emptyState(p),
                    for (final entry in _entries) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _buildEntry(entry, p),
                      ),
                    ],
                  ],
                ),
              ),
              if (_entries.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 0),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final suggestion in _suggestions)
                        _SuggestionChip(
                          icon: suggestion.icon,
                          label: suggestion.label,
                          onTap: () => _useSuggestion(suggestion.label),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              _composer(p),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState(AppPalette p) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.accentBright, AppColors.accent, AppColors.accentMid],
                ),
              ),
              child: const Icon(Icons.smart_toy, size: 28, color: AppColors.accentInk),
            ),
            const SizedBox(height: 16),
            Text(
              'Ask VEDA anything about your training',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: p.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your workout history, plan, and form data give VEDA the context to give precise, actionable answers.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: p.ink3, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntry(_ChatEntry entry, AppPalette p) {
    return switch (entry.type) {
      _EntryType.message => _Bubble(message: entry.message!),
      _EntryType.typing => _TypingIndicator(palette: p),
      _EntryType.error => _ErrorBubble(
          message: entry.errorMessage!,
          originalPrompt: entry.originalPrompt!,
          onRetry: () => _retry(entry.originalPrompt!),
          palette: p,
        ),
    };
  }

  /// Gradient assistant orb (sample `.orb`).
  Widget _orb() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.accentBright, AppColors.accent, AppColors.accentMid],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withAlpha(128),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: const Icon(
        Icons.smart_toy,
        size: 20,
        color: AppColors.accentInk,
      ),
    );
  }

  /// Message input bar: gradient fade, pill field and round send button.
  Widget _composer(AppPalette p) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0, 0.3, 1],
          colors: [p.composerTop, p.composerBottom, p.composerBottom],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              textInputAction: TextInputAction.send,
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => _send(),
              onChanged: (_) => setState(() {}),
              style: TextStyle(fontSize: 13.5, color: p.ink),
              decoration: InputDecoration(
                hintText: 'Type your message…',
                prefixIcon: Icon(
                  Icons.auto_awesome,
                  size: 18,
                  color: p.accentDeep,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 13,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: BorderSide(color: p.fieldBorder, width: 1.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: BorderSide(color: p.fieldBorder, width: 1.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: const BorderSide(
                    color: AppColors.accentMid,
                    width: 1.8,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 9),
          _sendButton(p),
        ],
      ),
    );
  }

  Widget _sendButton(AppPalette p) {
    final enabled = _controller.text.trim().isNotEmpty;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? _send : null,
          customBorder: const CircleBorder(),
          child: Ink(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.accentBright, AppColors.accentMid],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withAlpha(115),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.arrow_upward,
              size: 22,
              color: AppColors.accentInk,
            ),
          ),
        ),
      ),
    );
  }
}

/// Entry in the chat list: message, typing indicator, or error with retry.
class _ChatEntry {
  _ChatEntry._({
    required this.type,
    this.message,
    this.errorMessage,
    this.originalPrompt,
  });

  final _EntryType type;
  final ChatMessage? message;
  final String? errorMessage;
  final String? originalPrompt;

  factory _ChatEntry.message(ChatMessage msg) => _ChatEntry._(
        type: _EntryType.message,
        message: msg,
      );

  factory _ChatEntry.typing() => _ChatEntry._(type: _EntryType.typing);

  factory _ChatEntry.error(String error, String originalPrompt) => _ChatEntry._(
        type: _EntryType.error,
        errorMessage: error,
        originalPrompt: originalPrompt,
      );
}

enum _EntryType { message, typing, error }

/// One chat row: coach bubble (glass, left) or user bubble (gradient, right).
class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final isUser = message.role == ChatRole.user;
    final maxWidth = MediaQuery.sizeOf(context).width * 0.82;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
          decoration: isUser
              ? BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.accentBright, AppColors.accentMid],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(7),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accent.withAlpha(102),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                )
              : BoxDecoration(
                  color: p.glass,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                    bottomLeft: Radius.circular(7),
                    bottomRight: Radius.circular(20),
                  ),
                  border: Border.all(color: p.border, width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: p.shadowSoft,
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message.text,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.5,
                  color: isUser ? AppColors.accentInk : p.ink,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                _formatTime(message.createdAt),
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: isUser
                      ? AppColors.accentInk.withAlpha(166)
                      : p.ink3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final suffix = dt.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $suffix';
  }
}

/// Typing indicator shown while waiting for VEDA response.
class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator({required this.palette});

  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.82),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
          decoration: BoxDecoration(
            color: palette.glass,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(7),
              bottomRight: Radius.circular(20),
            ),
            border: Border.all(color: palette.border, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: palette.shadowSoft,
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: _TypingDots(color: palette.accentDeep),
        ),
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots({required this.color});

  final Color color;

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final phase = (_controller.value * 2 * math.pi) - (i * 0.5);
          final scale = (0.5 + 0.5 * math.sin(phase)).clamp(0.3, 1.0);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Transform.scale(
              scale: scale,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: widget.color,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// Error bubble with retry action.
class _ErrorBubble extends StatelessWidget {
  const _ErrorBubble({
    required this.message,
    required this.originalPrompt,
    required this.onRetry,
    required this.palette,
  });

  final String message;
  final String originalPrompt;
  final VoidCallback onRetry;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.82),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
          decoration: BoxDecoration(
            color: AppColors.danger.withAlpha(20),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(7),
              bottomRight: Radius.circular(20),
            ),
            border: Border.all(color: AppColors.danger.withAlpha(100), width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.error_outline, size: 16, color: AppColors.danger),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      message,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.5,
                        color: AppColors.danger,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Retry'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: BorderSide(color: AppColors.danger),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Quick-prompt chip under the conversation (sample `.chip`).
class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: p.glass,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: p.border, width: 1.2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: p.accentDeep),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: p.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Glass square icon button (sample `.icon-btn`).
class _IconBox extends StatelessWidget {
  const _IconBox(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: p.glass,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: p.shadowSoft,
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Icon(icon, size: 21, color: p.ink),
    );
  }
}

class _Suggestion {
  const _Suggestion({required this.icon, required this.label});

  final IconData icon;
  final String label;
}