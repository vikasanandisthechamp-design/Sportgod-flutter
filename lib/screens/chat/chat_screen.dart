import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../config/env_config.dart';
import '../../providers/auth_provider.dart';
import '../../services/chat_storage.dart';
import '../../theme/app_theme.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  final List<ChatMessage> _messages = [];
  final ChatStorage _storage = ChatStorage();
  bool _sending = false;

  /// The AI message currently being streamed (null when not streaming).
  ChatMessage? _streamingMessage;

  final _starters = [
    'Who has the best strike rate in IPL 2026?',
    'Which team is likely to top the table?',
    'Best fantasy captain picks for today',
    'Compare Virat Kohli vs Rohit Sharma stats',
  ];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final saved = await _storage.loadMessages();
    if (saved.isNotEmpty && mounted) {
      setState(() => _messages.addAll(saved));
      _scrollBottom();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // ── Send & receive ──────────────────────────────────────────────────

  Future<void> _send(String text) async {
    if (text.trim().isEmpty) return;
    HapticFeedback.lightImpact();
    _ctrl.clear();

    final userMsg = ChatMessage(text: text, isUser: true);
    setState(() {
      _messages.add(userMsg);
      _sending = true;
    });
    _scrollBottom();
    await _storage.saveMessages(_messages);

    final token = context.read<AuthProvider>().accessToken;

    // Build conversation history (last 10 messages for context)
    final history = (_messages.length > 10
            ? _messages.sublist(_messages.length - 10)
            : _messages)
        .map((m) => {
              'role': m.isUser ? 'user' : 'assistant',
              'content': m.text,
            })
        .toList();

    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    final body = json.encode({'question': text, 'history': history});

    // Try streaming endpoint first, fall back to non-streaming.
    final success = await _tryStream(headers, body);
    if (!success) {
      await _sendNonStreaming(headers, body);
    }

    _sending = false;
    _streamingMessage = null;
    if (mounted) setState(() {});
    _scrollBottom();
  }

  /// Attempts to use the streaming endpoint. Returns `true` if the endpoint
  /// exists and the response was consumed successfully.
  Future<bool> _tryStream(Map<String, String> headers, String body) async {
    try {
      final request = http.Request(
        'POST',
        Uri.parse('${Env.apiBaseUrl}/api/v1/chat/stream'),
      );
      request.headers.addAll(headers);
      request.body = body;

      final streamedResponse =
          await request.send().timeout(const Duration(seconds: 5));

      if (streamedResponse.statusCode == 404 ||
          streamedResponse.statusCode == 405) {
        // Streaming not supported — fall back.
        return false;
      }

      if (streamedResponse.statusCode != 200) {
        return false;
      }

      // Streaming is available — consume the response chunks.
      final buffer = StringBuffer();
      final timestamp = DateTime.now();

      setState(() {
        _streamingMessage = ChatMessage(text: '', isUser: false, timestamp: timestamp);
        _sending = false; // hide typing dots, show the streaming bubble instead
      });
      _scrollBottom();

      await for (final chunk
          in streamedResponse.stream.transform(utf8.decoder)) {
        buffer.write(chunk);
        // Replace the streaming message in-place.
        setState(() {
          _streamingMessage =
              ChatMessage(text: buffer.toString(), isUser: false, timestamp: timestamp);
        });
        _scrollBottom();
      }

      final finalText = buffer.toString().trim();
      final finalMsg = ChatMessage(
        text: finalText.isNotEmpty
            ? finalText
            : 'No response received. Please try again.',
        isUser: false,
        timestamp: timestamp,
      );
      setState(() {
        _streamingMessage = null;
        _messages.add(finalMsg);
      });
      await _storage.saveMessages(_messages);
      return true;
    } catch (_) {
      // Any failure (timeout on connect, network error, etc.) — fall back.
      setState(() => _streamingMessage = null);
      return false;
    }
  }

  /// Original non-streaming POST request.
  Future<void> _sendNonStreaming(
      Map<String, String> headers, String body) async {
    try {
      final res = await http
          .post(
            Uri.parse('${Env.apiBaseUrl}/api/v1/chat'),
            headers: headers,
            body: body,
          )
          .timeout(const Duration(seconds: 30));

      if (res.statusCode == 200) {
        final data = json.decode(res.body) as Map<String, dynamic>;
        final reply = (data['answer'] ??
                data['response'] ??
                data['message'] ??
                '')
            .toString()
            .trim();
        setState(() => _messages.add(ChatMessage(
              text: reply.isNotEmpty
                  ? reply
                  : 'No response received. Please try again.',
              isUser: false,
            )));
      } else if (res.statusCode == 503) {
        setState(() => _messages.add(ChatMessage(
              text:
                  'AI model is temporarily unavailable. Please try again in a moment.',
              isUser: false,
            )));
      } else {
        setState(() => _messages.add(ChatMessage(
              text:
                  'Sorry, I could not process that request (${res.statusCode}). Please try again.',
              isUser: false,
            )));
      }
    } on http.ClientException {
      setState(() => _messages.add(ChatMessage(
            text:
                'Network error. Please check your connection and try again.',
            isUser: false,
          )));
    } catch (_) {
      setState(() => _messages.add(ChatMessage(
            text:
                'Request timed out. The AI may be busy — please try again.',
            isUser: false,
          )));
    }
    await _storage.saveMessages(_messages);
  }

  // ── Clear history ───────────────────────────────────────────────────

  Future<void> _clearChat() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SGColors.card,
        title: const Text('Clear chat?',
            style: TextStyle(color: SGColors.textPrimary)),
        content: const Text('This will delete your entire conversation history.',
            style: TextStyle(color: SGColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('Clear', style: TextStyle(color: Color(0xFFEF4444))),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _storage.clear();
      setState(() => _messages.clear());
    }
  }

  // ── Copy message ────────────────────────────────────────────────────

  void _copyMessage(ChatMessage msg) {
    Clipboard.setData(ClipboardData(text: msg.text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Message copied to clipboard'),
        backgroundColor: SGColors.card,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ── Scroll ──────────────────────────────────────────────────────────

  void _scrollBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Build ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bool showTypingDots = _sending && _streamingMessage == null;

    // Total items = messages + optional streaming bubble + optional typing dots
    final int extraItems =
        (_streamingMessage != null ? 1 : 0) + (showTypingDots ? 1 : 0);

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF00E5A8), Color(0xFF00C9FF)]),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
                child: Icon(Icons.psychology_rounded,
                    size: 16, color: Color(0xFF0F0F11))),
          ),
          const SizedBox(width: 10),
          const Text('SportsGPT'),
        ]),
        actions: [
          if (_messages.isNotEmpty)
            IconButton(
              onPressed: _clearChat,
              icon: const Icon(Icons.delete_outline_rounded, size: 22),
              tooltip: 'Clear chat',
              color: SGColors.textSecondary,
            ),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: _messages.isEmpty && _streamingMessage == null
              ? _emptyState()
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  itemCount: _messages.length + extraItems,
                  itemBuilder: (_, i) {
                    if (i < _messages.length) {
                      return _messageBubble(_messages[i]);
                    }
                    // Streaming bubble (comes right after existing messages)
                    if (_streamingMessage != null && i == _messages.length) {
                      return _messageBubble(_streamingMessage!);
                    }
                    // Typing indicator
                    return const _AnimatedTypingIndicator();
                  },
                ),
        ),

        // Input
        Container(
          padding: EdgeInsets.fromLTRB(
              16, 8, 8, MediaQuery.of(context).padding.bottom + 8),
          decoration: BoxDecoration(
            color: SGColors.card,
            border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
          ),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'Ask about cricket...',
                  hintStyle: TextStyle(color: SGColors.textMuted),
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onSubmitted: _send,
              ),
            ),
            IconButton(
              onPressed: _sending ? null : () => _send(_ctrl.text),
              icon: const Icon(Icons.send_rounded, size: 22),
              color: const Color(0xFF00E5A8),
            ),
          ]),
        ),
      ]),
    );
  }

  // ── Widgets ─────────────────────────────────────────────────────────

  Widget _emptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF00E5A8), Color(0xFF00C9FF)]),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Center(
                child: Icon(Icons.psychology_rounded,
                    size: 32, color: Color(0xFF0F0F11))),
          ),
          const SizedBox(height: 20),
          const Text('SportsGPT',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: SGColors.textPrimary)),
          const SizedBox(height: 6),
          const Text('Your AI cricket assistant',
              style: TextStyle(fontSize: 13, color: SGColors.textMuted)),
          const SizedBox(height: 28),
          ..._starters.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GestureDetector(
                  onTap: () => _send(s),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: Text(s,
                        style: const TextStyle(
                            fontSize: 13, color: SGColors.textSecondary)),
                  ),
                ),
              )),
        ]),
      ),
    );
  }

  Widget _messageBubble(ChatMessage msg) {
    final timeStr = DateFormat.jm().format(msg.timestamp); // e.g. "2:30 PM"

    return GestureDetector(
      onLongPress: () => _copyMessage(msg),
      child: Align(
        alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.78),
          margin: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment:
                msg.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: msg.isUser
                      ? const Color(0xFF00E5A8).withValues(alpha: 0.12)
                      : SGColors.card,
                  borderRadius: BorderRadius.circular(16).copyWith(
                    bottomRight:
                        msg.isUser ? const Radius.circular(4) : null,
                    bottomLeft:
                        !msg.isUser ? const Radius.circular(4) : null,
                  ),
                  border: Border.all(
                      color: msg.isUser
                          ? const Color(0xFF00E5A8).withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.06)),
                ),
                child: msg.isUser
                    ? Text(msg.text,
                        style: const TextStyle(
                            fontSize: 14, color: SGColors.textPrimary))
                    : MarkdownBody(
                        data: msg.text,
                        styleSheet: MarkdownStyleSheet(
                          p: const TextStyle(
                              fontSize: 14,
                              color: SGColors.textPrimary,
                              height: 1.5),
                          strong: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: SGColors.textPrimary),
                          code: TextStyle(
                            fontSize: 12,
                            color: const Color(0xFF00E5A8),
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.06),
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 4),
              Text(
                timeStr,
                style: const TextStyle(
                    fontSize: 10, color: SGColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Animated typing indicator ────────────────────────────────────────

class _AnimatedTypingIndicator extends StatefulWidget {
  const _AnimatedTypingIndicator();

  @override
  State<_AnimatedTypingIndicator> createState() =>
      _AnimatedTypingIndicatorState();
}

class _AnimatedTypingIndicatorState extends State<_AnimatedTypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: SGColors.card,
          borderRadius: BorderRadius.circular(16)
              .copyWith(bottomLeft: const Radius.circular(4)),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (_, __) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                // Each dot is offset by 0.2 in the animation cycle.
                final double phase = (_controller.value + i * 0.2) % 1.0;
                // Map phase to a smooth bounce using sin.
                final double offset = -3 * sin(phase * pi);
                return Padding(
                  padding: EdgeInsets.only(right: i < 2 ? 4 : 0),
                  child: Transform.translate(
                    offset: Offset(0, offset),
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: SGColors.textMuted
                            .withValues(alpha: 0.4 + 0.4 * sin(phase * pi)),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                );
              }),
            );
          },
        ),
      ),
    );
  }
}
