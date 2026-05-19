import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class FavoritesService {
  static const _key = 'favorite_matches';

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

  Future<void> toggleFavorite(String matchId) async {
    final ids = await _read();
    if (ids.contains(matchId)) {
      ids.remove(matchId);
    } else {
      ids.add(matchId);
    }
    await _write(ids);
  }

  Future<bool> isFavorite(String matchId) async {
    final ids = await _read();
    return ids.contains(matchId);
  }

  Future<List<String>> getFavorites() async {
    final ids = await _read();
    return ids.toList();
  }
}
