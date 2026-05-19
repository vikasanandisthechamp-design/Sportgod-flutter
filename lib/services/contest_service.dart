import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/env_config.dart';
import '../models/contest_models.dart';

class ContestService {
  final http.Client _client;
  final String? _token;

  ContestService({http.Client? client, String? token})
      : _client = client ?? http.Client(),
        _token = token;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  // ── List contests for a match ─────────────────────────────────────
  Future<List<Contest>> getContests(String matchId, {String status = 'open'}) async {
    try {
      final res = await _client
          .get(
            Uri.parse('${Env.webBaseUrl}/api/v2/contests?match_id=$matchId&status=$status'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 12));

      if (res.statusCode == 200) {
        final body = json.decode(res.body) as Map<String, dynamic>;
        final list = (body['contests'] ?? []) as List;
        return list.map((c) => Contest.fromJson(c as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return [];
  }

  // ── Create a contest ──────────────────────────────────────────────
  Future<Map<String, dynamic>> createContest({
    required String matchId,
    required String contestType,
    String? title,
    String? matchName,
    String? homeTeam,
    String? awayTeam,
    String? homeLogo,
    String? awayLogo,
    int entryFee = 0,
    int maxPlayers = 50,
  }) async {
    final res = await _client
        .post(
          Uri.parse('${Env.webBaseUrl}/api/v2/contests/create'),
          headers: _headers,
          body: json.encode({
            'match_id': matchId,
            'contest_type': contestType,
            if (title != null) 'title': title,
            'match_name': matchName ?? '',
            'home_team': homeTeam ?? '',
            'away_team': awayTeam ?? '',
            'home_logo': homeLogo ?? '',
            'away_logo': awayLogo ?? '',
            'entry_fee': entryFee,
            'max_players': maxPlayers,
          }),
        )
        .timeout(const Duration(seconds: 15));

    return json.decode(res.body) as Map<String, dynamic>;
  }

  // ── Join a contest ────────────────────────────────────────────────
  Future<Map<String, dynamic>> joinContest({
    String? contestId,
    String? inviteCode,
    required String teamCode,
  }) async {
    final res = await _client
        .post(
          Uri.parse('${Env.webBaseUrl}/api/v2/contests/join'),
          headers: _headers,
          body: json.encode({
            if (contestId != null) 'contest_id': contestId,
            if (inviteCode != null) 'invite_code': inviteCode,
            'team_code': teamCode,
          }),
        )
        .timeout(const Duration(seconds: 15));

    return json.decode(res.body) as Map<String, dynamic>;
  }

  // ── Get contest leaderboard ───────────────────────────────────────
  Future<Map<String, dynamic>> getLeaderboard({
    String? contestId,
    String? inviteCode,
  }) async {
    final query = contestId != null
        ? 'contest_id=$contestId'
        : 'invite_code=${inviteCode ?? ''}';

    try {
      final res = await _client
          .get(
            Uri.parse('${Env.webBaseUrl}/api/v2/contests/leaderboard?$query'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 12));

      if (res.statusCode == 200) {
        return json.decode(res.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return {};
  }

  // ── Get partner status ────────────────────────────────────────────
  Future<Map<String, dynamic>> getPartnerStatus() async {
    try {
      final res = await _client
          .get(
            Uri.parse('${Env.webBaseUrl}/api/v2/partners'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 12));

      if (res.statusCode == 200) {
        return json.decode(res.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return {'isPartner': false};
  }

  // ── Apply to become a partner ─────────────────────────────────────
  Future<Map<String, dynamic>> applyPartner({String? bio}) async {
    final res = await _client
        .post(
          Uri.parse('${Env.webBaseUrl}/api/v2/partners/apply'),
          headers: _headers,
          body: json.encode({
            if (bio != null) 'bio': bio,
          }),
        )
        .timeout(const Duration(seconds: 15));

    return json.decode(res.body) as Map<String, dynamic>;
  }

  // ── Track referral ────────────────────────────────────────────────
  Future<void> trackReferral(String refCode, String refereeId) async {
    try {
      await _client
          .post(
            Uri.parse('${Env.webBaseUrl}/api/v2/referrals'),
            headers: _headers,
            body: json.encode({
              'ref_code': refCode,
              'referee_id': refereeId,
            }),
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {}
  }
}
