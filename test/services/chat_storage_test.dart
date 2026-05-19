import 'package:flutter_test/flutter_test.dart';
import 'package:sportgod/services/chat_storage.dart';

void main() {
  group('ChatMessage', () {
    test('toJson serializes correctly', () {
      final msg = ChatMessage(
        text: 'Hello',
        isUser: true,
        timestamp: DateTime.utc(2026, 5, 19, 12, 0),
      );
      final json = msg.toJson();
      expect(json['text'], 'Hello');
      expect(json['isUser'], true);
      expect(json['timestamp'], '2026-05-19T12:00:00.000Z');
    });

    test('fromJson deserializes correctly', () {
      final msg = ChatMessage.fromJson({
        'text': 'Hi there',
        'isUser': false,
        'timestamp': '2026-05-19T14:30:00.000Z',
      });
      expect(msg.text, 'Hi there');
      expect(msg.isUser, false);
      expect(msg.timestamp.hour, 14);
    });

    test('fromJson handles missing timestamp', () {
      final msg = ChatMessage.fromJson({
        'text': 'Test',
        'isUser': true,
      });
      expect(msg.text, 'Test');
      expect(msg.timestamp, isNotNull);
    });

    test('roundtrip serialization', () {
      final original = ChatMessage(text: 'Roundtrip', isUser: false);
      final restored = ChatMessage.fromJson(original.toJson());
      expect(restored.text, original.text);
      expect(restored.isUser, original.isUser);
    });
  });
}
