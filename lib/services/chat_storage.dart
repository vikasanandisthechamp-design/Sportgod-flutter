import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the last [_maxMessages] chat messages using SharedPreferences.
class ChatStorage {
  static const _key = 'chat_history';
  static const _maxMessages = 50;

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _preferences async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Save the current message list (trimmed to the most recent 50).
  Future<void> saveMessages(List<ChatMessage> messages) async {
    final prefs = await _preferences;
    final trimmed = messages.length > _maxMessages
        ? messages.sublist(messages.length - _maxMessages)
        : messages;
    final encoded = trimmed.map((m) => m.toJson()).toList();
    await prefs.setString(_key, json.encode(encoded));
  }

  /// Load persisted messages (returns empty list if none stored).
  Future<List<ChatMessage>> loadMessages() async {
    final prefs = await _preferences;
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = (json.decode(raw) as List).cast<Map<String, dynamic>>();
      return list.map((j) => ChatMessage.fromJson(j)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Remove all persisted messages.
  Future<void> clear() async {
    final prefs = await _preferences;
    await prefs.remove(_key);
  }
}

/// A single chat message that can be serialised to/from JSON.
class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'text': text,
        'isUser': isUser,
        'timestamp': timestamp.toIso8601String(),
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        text: json['text'] as String? ?? '',
        isUser: json['isUser'] as bool? ?? true,
        timestamp: json['timestamp'] != null
            ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
            : DateTime.now(),
      );
}
