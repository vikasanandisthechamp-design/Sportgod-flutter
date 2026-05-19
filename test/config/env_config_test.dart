import 'package:flutter_test/flutter_test.dart';
import 'package:sportgod/config/env_config.dart';

void main() {
  group('Env', () {
    test('apiBaseUrl has default value', () {
      expect(Env.apiBaseUrl, isNotEmpty);
      expect(Env.apiBaseUrl, contains('sportgod'));
    });

    test('wsBaseUrl has default value', () {
      expect(Env.wsBaseUrl, isNotEmpty);
      expect(Env.wsBaseUrl, startsWith('wss://'));
    });

    test('webBaseUrl has default value', () {
      expect(Env.webBaseUrl, isNotEmpty);
      expect(Env.webBaseUrl, contains('sportgod'));
    });

    test('supabaseUrl has default value', () {
      expect(Env.supabaseUrl, isNotEmpty);
      expect(Env.supabaseUrl, contains('supabase'));
    });

    test('supabaseAnonKey has default value', () {
      expect(Env.supabaseAnonKey, isNotEmpty);
      expect(Env.supabaseAnonKey, contains('eyJ'));
    });

    test('razorpayKeyId has default value', () {
      expect(Env.razorpayKeyId, isNotEmpty);
    });
  });
}
