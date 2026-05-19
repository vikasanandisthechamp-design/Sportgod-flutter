import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/env_config.dart';

class MatchFollowService {
  static const _key = 'followed_matches';

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _preferences async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  Future<Set<String>> _read() async {
    final prefs = await _preferences;
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return {};
    try {
      final list = (json.decode(raw) as List).cast<String>();
      return list.toSet();
    } catch (_) {
      return {};
    }
  }

  Future<void> _write(Set<String> ids) async {
    final prefs = await _preferences;
    await prefs.setString(_key, json.encode(ids.toList()));
  }

  /// Toggles the follow state for [matchId] and returns the new state.
  Future<bool> toggleFollow(String matchId) async {
    final ids = await _read();
    final following = !ids.contains(matchId);
    if (following) {
      ids.add(matchId);
    } else {
      ids.remove(matchId);
    }
    await _write(ids);

    // Fire-and-forget backend registration
    _syncToBackend(matchId, following);

    return following;
  }

  Future<bool> isFollowing(String matchId) async {
    final ids = await _read();
    return ids.contains(matchId);
  }

  Future<List<String>> getFollowed() async {
    final ids = await _read();
    return ids.toList();
  }

  /// Best-effort POST to register/unregister follow on backend.
  void _syncToBackend(String matchId, bool follow) {
    try {
      http.post(
        Uri.parse('${Env.apiBaseUrl}/api/v1/notifications/follow-match'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'match_id': matchId, 'follow': follow}),
      ).timeout(const Duration(seconds: 8)).catchError((_) {});
    } catch (_) {
      // Fire-and-forget — never fail the UI
    }
  }
}
