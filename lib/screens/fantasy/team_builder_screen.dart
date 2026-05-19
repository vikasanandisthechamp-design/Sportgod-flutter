import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../config/env_config.dart';
import '../../models/cricket_models.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/socket_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/debounce.dart';
import '../../widgets/shimmer_loading.dart';

// ── Fantasy Points System ──────────────────────────────────────────────
// Mirrors the backend scoring — batting + bowling + fielding + bonus

class FantasyPoints {
  // Batting
  static const double perRun          = 1;
  static const double perFour         = 1;   // bonus per boundary
  static const double perSix          = 2;   // bonus per six
  static const double halfCentury     = 8;   // 50 runs bonus
  static const double century         = 16;  // 100 runs bonus
  static const double duckPenalty     = -2;  // out for 0
  static const double strikeRateBonus75  = -2; // SR < 50 in T20
  static const double strikeRateBonus100 = 0;
  static const double strikeRateBonus150 = 4;  // SR > 150

  // Bowling
  static const double perWicket       = 25;
  static const double perMaiden       = 8;
  static const double threeWickets    = 4;   // 3-wicket bonus
  static const double fourWickets     = 8;   // 4-wicket haul bonus
  static const double fiveWickets     = 16;  // 5-wicket haul bonus
  static const double economyBonusLow = 6;   // econ < 5
  static const double economyBonusMid = 4;   // econ 5-6
  static const double economyPenaltyHigh = -2; // econ > 10
  static const double economyPenaltyVHigh = -4; // econ > 12

  // Fielding
  static const double perCatch        = 8;
  static const double perStumping     = 12;
  static const double perRunOut       = 6;

  // Captain / VC multipliers
  static const double captainMultiplier     = 2.0;
  static const double viceCaptainMultiplier = 1.5;

  /// Calculate total batting points for a player
  static double calcBatting(BattingRow b, {String matchType = 'T20'}) {
    double pts = 0;
    pts += b.runs * perRun;
    pts += b.fours * perFour;
    pts += b.sixes * perSix;
    if (b.runs >= 100) {
      pts += century;
    } else if (b.runs >= 50) {
      pts += halfCentury;
    }
    if (b.runs == 0 && !b.isNotOut && b.balls > 0) {
      pts += duckPenalty;
    }

    // Strike rate bonus/penalty (only for T20/ODI with min 10 balls)
    if (b.balls >= 10 && (matchType == 'T20' || matchType == 'ODI')) {
      if (b.strikeRate > 150) {
        pts += strikeRateBonus150;
      } else if (b.strikeRate < 50) {
        pts += strikeRateBonus75;
      }
    }

    return pts;
  }

  /// Calculate total bowling points for a player
  static double calcBowling(BowlingRow b) {
    double pts = 0;
    pts += b.wickets * perWicket;
    pts += b.maidens * perMaiden;

    // Wicket haul bonuses
    if (b.wickets >= 5) {
      pts += fiveWickets;
    } else if (b.wickets >= 4) {
      pts += fourWickets;
    } else if (b.wickets >= 3) {
      pts += threeWickets;
    }

    // Economy bonus/penalty (min 2 overs bowled)
    if (b.overs >= 2) {
      if (b.economy < 5) {
        pts += economyBonusLow;
      } else if (b.economy < 6) {
        pts += economyBonusMid;
      } else if (b.economy > 12) {
        pts += economyPenaltyVHigh;
      } else if (b.economy > 10) {
        pts += economyPenaltyHigh;
      }
    }

    return pts;
  }

  /// Calculate total for a player from scorecard
  static double calcTotal({
    required String playerId,
    required Scorecard scorecard,
    required String matchType,
    bool isCaptain = false,
    bool isViceCaptain = false,
  }) {
    double pts = 0;

    // Batting points
    for (final b in scorecard.batting) {
      if (b.playerId == playerId) {
        pts += calcBatting(b, matchType: matchType);
      }
    }

    // Bowling points
    for (final b in scorecard.bowling) {
      if (b.playerId == playerId) {
        pts += calcBowling(b);
      }
    }

    // Apply C/VC multiplier
    if (isCaptain) {
      pts *= captainMultiplier;
    } else if (isViceCaptain) {
      pts *= viceCaptainMultiplier;
    }

    return pts;
  }
}

// ── Team Builder Screen ─────────────────────────────────────────────────

class TeamBuilderScreen extends StatefulWidget {
  final String matchId;
  const TeamBuilderScreen({super.key, required this.matchId});

  @override
  State<TeamBuilderScreen> createState() => _TeamBuilderScreenState();
}

class _TeamBuilderScreenState extends State<TeamBuilderScreen> {
  final _api = ApiService();
  final _throttle = Throttle(cooldown: Duration(seconds: 2));
  List<Map<String, dynamic>> _players = [];
  final Set<String> _selected = {};
  String? _captain;
  String? _viceCaptain;
  bool _loading = true;
  bool _submitting = false;
  bool _teamJustSubmitted = false;
  String? _teamCode;
  String? _error;
  double _budget = 100;
  double _spent = 0;

  // Match status — locks team creation if match has started
  CricketMatch? _match;
  bool _matchStarted = false;
  bool _hasExistingTeam = false;

  // Live scoring
  Scorecard? _scorecard;
  SocketService? _socket;
  StreamSubscription? _snapshotSub;
  final Map<String, double> _livePoints = {};
  double _totalTeamPoints = 0;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() { _loading = true; _error = null; });

    final token = context.read<AuthProvider>().accessToken;

    try {
      // Load match status first
      _match = await _api.getMatch(widget.matchId);
      _matchStarted = _match?.hasStarted ?? false;

      // Check if user already has a team for this match
      await _checkExistingTeam(token);

      // Load players
      await _loadPlayers(token);

      // If match is live/finished, load scorecard and start live updates
      if (_matchStarted) {
        _scorecard = await _api.getScorecard(widget.matchId);
        _calcLivePoints();
        _connectSocket();
      }
    } catch (e) {
      _error = 'Failed to load: ${e.toString()}';
    }

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _checkExistingTeam(String? token) async {
    if (token == null) return;
    try {
      // Backend returns ALL teams for this user — filter by match_id client-side
      final res = await http.get(
        Uri.parse('${Env.apiBaseUrl}/api/v1/fantasy/user/teams'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final allTeams = (data['teams'] ?? data['data'] ?? []) as List;
        // Find team for this match
        final matchTeam = allTeams.cast<Map<String, dynamic>>().where(
          (t) => t['match_id']?.toString() == widget.matchId,
        ).toList();

        if (matchTeam.isNotEmpty) {
          final team = matchTeam.first;
          _hasExistingTeam = true;
          // Restore saved players — backend stores full player objects
          final players = (team['players'] ?? []) as List;
          for (final p in players.cast<Map<String, dynamic>>()) {
            final id = p['id']?.toString() ?? '';
            if (id.isNotEmpty) {
              _selected.add(id);
              if (p['is_captain'] == true) _captain = id;
              if (p['is_vc'] == true) _viceCaptain = id;
            }
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _loadPlayers(String? token) async {
    try {
      // Correct endpoint: /squad/{match_id} returns players with credits + selection %
      final res = await http.get(
        Uri.parse('${Env.apiBaseUrl}/api/v1/fantasy/squad/${widget.matchId}'),
        headers: {if (token != null) 'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final players = (data['players'] ?? data['data'] ?? []) as List;
        _players = players.cast<Map<String, dynamic>>();
        _budget = (data['budget'] ?? 100).toDouble();

        // Recalculate spent budget if team was restored
        _spent = 0;
        for (final p in _players) {
          if (_selected.contains(p['id'].toString())) {
            _spent += (p['credits'] ?? p['cost'] ?? 8.0).toDouble();
          }
        }
      } else {
        _error = 'Failed to load players';
      }
    } catch (_) {
      _error = 'Network error loading players';
    }
  }

  void _connectSocket() {
    _socket = SocketService(widget.matchId);
    _snapshotSub = _socket!.snapshotStream.listen((msg) {
      if (!mounted) return;
      if (msg['scorecard'] != null) {
        try {
          _scorecard = Scorecard.fromJson(msg['scorecard']);
          _calcLivePoints();
          setState(() {});
        } catch (_) {}
      }
    });
    _socket!.connect();
  }

  void _calcLivePoints() {
    if (_scorecard == null || _selected.isEmpty) return;
    final matchType = _match?.matchType ?? 'T20';

    _livePoints.clear();
    _totalTeamPoints = 0;

    for (final pid in _selected) {
      final pts = FantasyPoints.calcTotal(
        playerId: pid,
        scorecard: _scorecard!,
        matchType: matchType,
        isCaptain: pid == _captain,
        isViceCaptain: pid == _viceCaptain,
      );
      _livePoints[pid] = pts;
      _totalTeamPoints += pts;
    }
  }

  void _togglePlayer(Map<String, dynamic> player) {
    if (_matchStarted) return; // Locked after match starts

    HapticFeedback.selectionClick();
    final id = player['id'].toString();
    final cost = (player['credits'] ?? player['cost'] ?? 8.0).toDouble();

    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
        _spent -= cost;
        if (_captain == id) _captain = null;
        if (_viceCaptain == id) _viceCaptain = null;
      } else {
        if (_selected.length >= 11) return;
        if (_spent + cost > _budget) return;
        _selected.add(id);
        _spent += cost;
      }
    });
  }

  Future<void> _submitTeam() async {
    HapticFeedback.mediumImpact();
    if (_matchStarted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Team is locked — match has already started')),
      );
      return;
    }

    if (_selected.length != 11 || _captain == null || _viceCaptain == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select 11 players, a Captain and Vice Captain')),
      );
      return;
    }

    setState(() => _submitting = true);
    final token = context.read<AuthProvider>().accessToken;
    if (token == null) {
      setState(() => _submitting = false);
      return;
    }

    try {
      // Build full player objects as required by /team/submit
      final selectedPlayers = _players
          .where((p) => _selected.contains(p['id']?.toString()))
          .map((p) => {
                'id':         p['id']?.toString() ?? '',
                'name':       p['name'] ?? p['player_name'] ?? '',
                'role':       p['role'] ?? p['position'] ?? 'BAT',
                'team':       p['team'] ?? p['team_id'] ?? '',
                'credits':    (p['credits'] ?? p['cost'] ?? 8.0).toDouble(),
                'is_captain': p['id']?.toString() == _captain,
                'is_vc':      p['id']?.toString() == _viceCaptain,
              })
          .toList();

      final res = await http.post(
        Uri.parse('${Env.apiBaseUrl}/api/v1/fantasy/team/submit'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'match_id':   widget.matchId,
          'contest_id': 'public',
          'players':    selectedPlayers,
        }),
      );

      if (mounted) {
        if (res.statusCode == 200 || res.statusCode == 201) {
          final data = json.decode(res.body);
          setState(() {
            _teamJustSubmitted = true;
            _hasExistingTeam = true;
            _teamCode = data['team_code'] ?? data['teamCode'] ?? '';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Team submitted!'), backgroundColor: Color(0xFF00E5A8)),
          );
        } else {
          final data = json.decode(res.body);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['error'] ?? data['detail'] ?? 'Failed to submit team')),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Network error. Check connection.')),
        );
      }
    }
    if (mounted) setState(() => _submitting = false);
  }

  @override
  void dispose() {
    _snapshotSub?.cancel();
    _socket?.dispose();
    _api.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_matchStarted && _hasExistingTeam ? 'My Team' : 'Build Team'),
        actions: [
          if (_matchStarted && _totalTeamPoints > 0)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E5A8).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_totalTeamPoints.toStringAsFixed(1)} pts',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF00E5A8)),
                ),
              )),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E5A8).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_selected.length}/11',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF00E5A8)),
                ),
              )),
            ),
        ],
      ),
      body: _loading
          ? const ShimmerList(itemCount: 4)
          : _error != null
              ? _buildErrorState()
              : Column(
                  children: [
                    // Match started banner
                    if (_matchStarted)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        color: _match!.isLive
                            ? SGColors.live.withValues(alpha: 0.1)
                            : SGColors.textMuted.withValues(alpha: 0.1),
                        child: Row(children: [
                          Icon(
                            _match!.isLive ? Icons.lock_clock_rounded : Icons.lock_rounded,
                            size: 16,
                            color: _match!.isLive ? SGColors.live : SGColors.textMuted,
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(
                            _match!.isLive
                                ? 'Match is LIVE — team is locked. Watching points update in real time.'
                                : 'Match has ended — team is locked.',
                            style: TextStyle(
                              fontSize: 12,
                              color: _match!.isLive ? SGColors.live : SGColors.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          )),
                        ]),
                      ),

                    // Budget bar (only shown when building)
                    if (!_matchStarted)
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        color: SGColors.card,
                        child: Row(children: [
                          const Text('Budget: ', style: TextStyle(fontSize: 12, color: SGColors.textMuted)),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: _budget > 0 ? _spent / _budget : 0,
                                backgroundColor: Colors.white.withValues(alpha: 0.08),
                                valueColor: AlwaysStoppedAnimation(
                                  _spent / _budget > 0.9 ? Colors.redAccent : const Color(0xFF00E5A8),
                                ),
                                minHeight: 6,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '${(_budget - _spent).toStringAsFixed(1)} left',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: SGColors.textPrimary),
                          ),
                        ]),
                      ),

                    // Total team points (shown during/after match)
                    if (_matchStarted && _hasExistingTeam)
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        color: SGColors.card,
                        child: Row(children: [
                          const Icon(Icons.stars_rounded, size: 20, color: Color(0xFFFFD700)),
                          const SizedBox(width: 10),
                          const Text('Total Team Points', style: TextStyle(fontSize: 13, color: SGColors.textMuted)),
                          const Spacer(),
                          Text(
                            _totalTeamPoints.toStringAsFixed(1),
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFFFFD700)),
                          ),
                        ]),
                      ),

                    // Player list
                    Expanded(
                      child: _players.isEmpty
                          ? const Center(child: Text('No players available', style: TextStyle(color: SGColors.textMuted)))
                          : ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: _players.length,
                              itemBuilder: (_, i) => _playerCard(_players[i]),
                            ),
                    ),

                    // Submit button (only if match hasn't started)
                    if (!_matchStarted && !_hasExistingTeam)
                      SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _selected.length == 11 && !_submitting
                                  ? () => _throttle.call(() => _submitTeam())
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00E5A8),
                                foregroundColor: const Color(0xFF0F0F11),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              child: _submitting
                                  ? const SizedBox(width: 22, height: 22,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F0F11)))
                                  : const Text('Submit Team', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                            ),
                          ),
                        ),
                      ),

                    // Contest CTA — shown after team submitted
                    if (_teamJustSubmitted)
                      SafeArea(
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00E5A8).withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFF00E5A8).withValues(alpha: 0.2)),
                                ),
                                child: Column(
                                  children: [
                                    const Icon(Icons.check_circle_rounded, size: 36, color: Color(0xFF00E5A8)),
                                    const SizedBox(height: 8),
                                    const Text('Team Locked In!',
                                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: SGColors.textPrimary)),
                                    const SizedBox(height: 4),
                                    const Text('Now join a contest to compete',
                                        style: TextStyle(fontSize: 13, color: SGColors.textMuted)),
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: SizedBox(
                                            height: 48,
                                            child: ElevatedButton.icon(
                                              onPressed: () {
                                                context.push('/contests/${widget.matchId}?team_code=${_teamCode ?? ''}');
                                              },
                                              icon: const Icon(Icons.public_rounded, size: 18),
                                              label: const Text('PUBLIC ARENA',
                                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFF00E5A8),
                                                foregroundColor: const Color(0xFF0F0F11),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: SizedBox(
                                            height: 48,
                                            child: ElevatedButton.icon(
                                              onPressed: () {
                                                context.push('/contests/${widget.matchId}?team_code=${_teamCode ?? ''}&tab=private');
                                              },
                                              icon: const Icon(Icons.lock_rounded, size: 18),
                                              label: const Text('PRIVATE GAME',
                                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFF8B5CF6),
                                                foregroundColor: Colors.white,
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.cloud_off_rounded, size: 48, color: SGColors.textMuted),
          const SizedBox(height: 16),
          Text(_error!, style: const TextStyle(color: SGColors.textMuted, fontSize: 14), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _loadAll,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Retry'),
          ),
        ]),
      ),
    );
  }

  Widget _playerCard(Map<String, dynamic> player) {
    final id = player['id'].toString();
    final selected = _selected.contains(id);
    final name = player['name'] ?? player['player_name'] ?? '';
    final role = player['role'] ?? player['playing_role'] ?? '';
    final team = player['team'] ?? player['team_short'] ?? '';
    final cost = (player['credits'] ?? player['cost'] ?? 8.0).toDouble();
    final isCap = _captain == id;
    final isVC = _viceCaptain == id;
    final livePts = _livePoints[id];

    // Breakdown for tooltip
    String ptsLabel = '';
    if (_matchStarted && livePts != null) {
      final multiplier = isCap ? ' (C 2x)' : isVC ? ' (VC 1.5x)' : '';
      ptsLabel = '${livePts.toStringAsFixed(1)} pts$multiplier';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF00E5A8).withValues(alpha: 0.06) : SGColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected ? const Color(0xFF00E5A8).withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: ListTile(
        onTap: _matchStarted ? null : () => _togglePlayer(player),
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: _roleColor(role).withValues(alpha: 0.15),
          child: Text(
            _roleShort(role),
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _roleColor(role)),
          ),
        ),
        title: Row(
          children: [
            Expanded(child: Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: SGColors.textPrimary))),
            if (isCap)
              Container(
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E5A8), borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('C', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF0F0F11))),
              ),
            if (isVC)
              Container(
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1), borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('VC', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white)),
              ),
          ],
        ),
        subtitle: Row(
          children: [
            Expanded(child: Text('$team  ·  $cost pts', style: const TextStyle(fontSize: 11, color: SGColors.textMuted))),
            if (ptsLabel.isNotEmpty)
              Text(
                ptsLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: (livePts ?? 0) >= 0 ? const Color(0xFF00E5A8) : Colors.redAccent,
                ),
              ),
          ],
        ),
        trailing: !_matchStarted && !selected
            ? const Icon(Icons.add_circle_outline, color: SGColors.textMuted, size: 22)
            : !_matchStarted && selected
                ? Row(mainAxisSize: MainAxisSize.min, children: [
                    _capButton('C', isCap, () => setState(() => _captain = isCap ? null : id)),
                    const SizedBox(width: 6),
                    _capButton('VC', isVC, () => setState(() => _viceCaptain = isVC ? null : id)),
                  ])
                : null, // No trailing when match is live
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      ),
    );
  }

  Widget _capButton(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        width: 30, height: 30,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active ? const Color(0xFF00E5A8) : Colors.transparent,
          border: Border.all(color: active ? const Color(0xFF00E5A8) : SGColors.textMuted),
        ),
        alignment: Alignment.center,
        child: Text(label, style: TextStyle(
          fontSize: 10, fontWeight: FontWeight.w800,
          color: active ? const Color(0xFF0F0F11) : SGColors.textMuted,
        )),
      ),
    );
  }

  Color _roleColor(String role) {
    switch (role.toLowerCase()) {
      case 'bat': case 'batter': return const Color(0xFF3B82F6);
      case 'bowl': case 'bowler': return const Color(0xFFA855F7);
      case 'all': case 'all-rounder': return const Color(0xFF00E5A8);
      case 'wk': case 'keeper': return const Color(0xFFFFD700);
      default: return SGColors.textMuted;
    }
  }

  String _roleShort(String role) {
    switch (role.toLowerCase()) {
      case 'bat': case 'batter': return 'BAT';
      case 'bowl': case 'bowler': return 'BWL';
      case 'all': case 'all-rounder': return 'AR';
      case 'wk': case 'keeper': return 'WK';
      default: return role.length >= 3 ? role.substring(0, 3).toUpperCase() : role.toUpperCase();
    }
  }
}
