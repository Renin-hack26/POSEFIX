import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../shared/app_back_button.dart';
import '../shared/grid_background.dart';

// UI-first canned conversation — phase P6 wires local rules + GROQ (PLANNING §5.6).
const _seedMessages = [
  _ChatMessage(
    isUser: false,
    text:
        'Hi Alex — I have your last session (96 reps, 91% form). What do you want to work on today?',
    time: '9:38 AM',
  ),
  _ChatMessage(
    isUser: true,
    text: 'Why did my form drop on push ups?',
    time: '9:39 AM',
  ),
  _ChatMessage(
    isUser: false,
    text:
        'Your hip angle sagged in rounds 2–3 — your core fatigued. Fix: squeeze glutes, reduce to 2 × 10 next session and add a 20s plank hold between rounds.',
    time: '9:39 AM',
  ),
];

// UI-first canned conversation — phase P6 wires local rules + GROQ (PLANNING §5.6).
const _cannedReply =
    'Noted — I added that to today’s plan. Keep it to 2 × 10 with a 20s plank hold between rounds, then log how the set felt so I can adjust the next session.';

// UI-first canned conversation — phase P6 wires local rules + GROQ (PLANNING §5.6).
const _suggestions = [
  (icon: Icons.edit_note, label: 'Adjust today’s plan'),
  (icon: Icons.query_stats, label: 'Explain my report'),
  (icon: Icons.restaurant_menu, label: 'High-protein meals'),
  (icon: Icons.bedtime, label: 'Sleep & recovery'),
];

/// 13 — VEDA assistant chat (sample/index.html): orb header, canned
/// conversation, suggestion chips and a working composer.
///
/// Pushed route — `AppBackButton` returns to the previous screen.
class VedaChatScreen extends StatefulWidget {
  const VedaChatScreen({super.key});

  @override
  State<VedaChatScreen> createState() => _VedaChatScreenState();
}

class _VedaChatScreenState extends State<VedaChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<_ChatMessage> _messages = List<_ChatMessage>.of(_seedMessages);

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Local clock label, e.g. "9:41 AM" (sample `.bubble .t`).
  String _nowLabel() {
    final now = DateTime.now();
    final hour = now.hour % 12 == 0 ? 12 : now.hour % 12;
    final minute = now.minute.toString().padLeft(2, '0');
    final suffix = now.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $suffix';
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

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(_ChatMessage(isUser: true, text: text, time: _nowLabel()));
      _controller.clear();
    });
    _scrollToEnd();
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      setState(() {
        _messages.add(
          _ChatMessage(isUser: false, text: _cannedReply, time: _nowLabel()),
        );
      });
      _scrollToEnd();
    });
  }

  void _useSuggestion(String label) {
    setState(() => _controller.text = label);
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
                    for (final message in _messages) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _Bubble(message: message),
                      ),
                    ],
                  ],
                ),
              ),
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
              _composer(p),
            ],
          ),
        ),
      ),
    );
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

/// One chat row: coach bubble (glass, left) or user bubble (gradient, right).
class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final maxWidth = MediaQuery.sizeOf(context).width * 0.82;
    return Align(
      alignment:
          message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
          decoration: message.isUser
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
                  color: message.isUser ? AppColors.accentInk : p.ink,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                message.time,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: message.isUser
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

/// Single chat entry — [isUser] picks the bubble side and palette.
class _ChatMessage {
  const _ChatMessage({
    required this.isUser,
    required this.text,
    required this.time,
  });

  final bool isUser;
  final String text;
  final String time;
}
