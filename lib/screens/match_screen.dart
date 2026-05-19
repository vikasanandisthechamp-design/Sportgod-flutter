import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/cricket_models.dart';
import '../services/api_service.dart';
import '../services/match_follow_service.dart';
import '../services/socket_service.dart';
import '../theme/app_theme.dart';
import '../widgets/match_header_widget.dart';
import '../widgets/live_scoreboard_widget.dart';
import '../widgets/commentary_feed_widget.dart';
import '../widgets/scorecard_table_widget.dart';
import '../widgets/ai_prediction_widget.dart';
import '../widgets/worm_chart_widget.dart';
import '../widgets/head_to_head_widget.dart';

class MatchScreen extends StatefulWidget {
  final String matchId;
  const MatchScreen({super.key, required this.matchId});

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen>
    with SingleTickerProviderStateMixin {

  final _api           = ApiService();
  final _followService = MatchFollowService();
  late  SocketService _socket;
  late  TabController _tabController;

  // Stream subscription handles — must be stored so they can be cancelled in
  // dispose().  Without these, the listeners are leaked: the SocketService
  // gets disposed but the anonymous listeners hold references to BuildContext
  // and setState, keeping the widget alive and firing setState on a dead widget.
  StreamSubscription<SocketState>?           _stateSub;
  StreamSubscription<Map<String, dynamic>>?  _snapshotSub;
  StreamSubscription<BallEvent>?             _ballSub;
  StreamSubscription<Map<String, dynamic>>?  _scorecardSub;
  StreamSubscription<List<BallEvent>>?       _commentarySub;

  CricketMatch? _match;
  Scorecard?    _scorecard;
  Prediction?   _prediction;
  final List<BallEvent> _commentary = [];

  SocketState _socketState = SocketState.connecting;
  bool        _loading     = true;
  bool        _ballFlash   = false;
  bool        _isFollowing = false;
  String?     _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _socket = SocketService(widget.matchId);

    _stateSub = _socket.stateStream.listen((s) {
      if (mounted) setState(() => _socketState = s);
    });

    _snapshotSub = _socket.snapshotStream.listen(_handleSnapshot);
    _ballSub     = _socket.ballStream.listen(_handleBall);

    // Live scorecard push: replaces the full scorecard on wickets / overs / scoring
    _scorecardSub = _socket.scorecardStream.listen(_handleScorecardUpdate);

    // Commentary batch: arrives after reconnect — merge without duplicating
    _commentarySub = _socket.commentaryStream.listen(_handleCommentaryHistory);

    _socket.connect();
    _loadInitialData();
    _loadFollowState();
  }

  Future<void> _loadFollowState() async {
    final following = await _followService.isFollowing(widget.matchId);
    if (mounted) setState(() => _isFollowing = following);
  }

  Future<void> _toggleFollow() async {
    HapticFeedback.selectionClick();
    final nowFollowing = await _followService.toggleFollow(widget.matchId);
    if (!mounted) return;
    setState(() => _isFollowing = nowFollowing);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(nowFollowing
          ? "You'll be notified about this match"
          : 'Notifications off for this match'),
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _loadInitialData() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });

    try {
      // Load match first — critical
      _match = await _api.getMatch(widget.matchId);
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
      return;
    }

    // Load others in parallel — non-critical (failures are graceful)
    try {
      final results = await Future.wait([
        _api.getScorecard(widget.matchId),
        _api.getCommentary(widget.matchId),
        _api.getPrediction(widget.matchId),
      ]);
      if (!mounted) return;
      _scorecard = results[0] as Scorecard?;
      final balls = results[1] as List<BallEvent>;
      if (balls.isNotEmpty) _commentary.addAll(balls.reversed);
      _prediction = results[2] as Prediction;
    } catch (_) {
      // Non-critical — match screen still works without scorecard/prediction
    }

    if (mounted) setState(() => _loading = false);
  }

  void _handleSnapshot(Map<String, dynamic> msg) {
    if (!mounted) return;
    setState(() {
      if (msg['match'] != null) {
        try { _match = CricketMatch.fromJson(msg['match']); } catch (_) {}
      }
      if (msg['scorecard'] != null) {
        try { _scorecard = Scorecard.fromJson(msg['scorecard']); } catch (_) {}
      }
      final balls = (msg['commentary'] ?? []) as List;
      if (balls.isNotEmpty) {
        try {
          final fresh = balls.map((b) => BallEvent.fromJson(b as Map<String, dynamic>)).toList();
          for (final b in fresh) {
            if (!_commentary.any((c) => c.ballId == b.ballId)) {
              _commentary.insert(0, b);
            }
          }
        } catch (_) {}
      }
      _loading = false;
    });
  }

  void _handleBall(BallEvent ball) {
    if (!mounted) return;
    setState(() {
      if (!_commentary.any((c) => c.ballId == ball.ballId)) {
        _commentary.insert(0, ball);
        if (_commentary.length > 100) _commentary.removeLast();
      }
      _ballFlash = true;
    });
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _ballFlash = false);
    });
  }

  /// Called on every `scorecard_update` push from the WebSocket.
  /// Replaces the entire scorecard so live stats (runs, wickets, overs) stay current.
  void _handleScorecardUpdate(Map<String, dynamic> data) {
    if (!mounted) return;
    try {
      final updated = Scorecard.fromJson(data);
      setState(() => _scorecard = updated);
    } catch (_) {
      // Malformed payload — keep last known scorecard
    }
  }

  /// Called on `commentary_history` — a batch of historical balls sent after reconnect.
  /// Merges new balls without duplicating entries already in [_commentary].
  void _handleCommentaryHistory(List<BallEvent> balls) {
    if (!mounted || balls.isEmpty) return;
    setState(() {
      for (final ball in balls) {
        if (!_commentary.any((c) => c.ballId == ball.ballId)) {
          _commentary.add(ball);
        }
      }
      // Keep most-recent first (ballId is "over.ball" e.g. "14.3" — parse as double)
      _commentary.sort((a, b) {
        final da = double.tryParse(a.ballId) ?? 0.0;
        final db = double.tryParse(b.ballId) ?? 0.0;
        return db.compareTo(da);
      });
      if (_commentary.length > 200) {
        _commentary.removeRange(200, _commentary.length);
      }
    });
  }

  @override
  void dispose() {
    // Cancel all stream subscriptions BEFORE disposing the socket.
    // This prevents setState() from being called on a disposed widget if a
    // stream event fires between socket.dispose() and super.dispose().
    _stateSub?.cancel();
    _snapshotSub?.cancel();
    _ballSub?.cancel();
    _scorecardSub?.cancel();
    _commentarySub?.cancel();

    _tabController.dispose();
    _socket.dispose();
    _api.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final match = _match;

    return Scaffold(
      appBar: AppBar(
        title: Text(match == null
          ? 'Loading...'
          : '${match.teamHome.short} vs ${match.teamAway.short}',
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isFollowing ? Icons.notifications_rounded : Icons.notifications_none_rounded,
              color: _isFollowing ? SGColors.primary : SGColors.textMuted,
              size: 22,
            ),
            onPressed: _toggleFollow,
            tooltip: _isFollowing ? 'Unfollow match' : 'Follow match',
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _ConnectionDot(state: _socketState),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Live'),
            Tab(text: 'Scorecard'),
            Tab(text: 'AI'),
          ],
        ),
      ),
      body: _loading
        ? const _ShimmerLoading()
        : _error != null
          ? _ErrorView(error: _error!, onRetry: _loadInitialData)
          : match == null
            ? const _ShimmerLoading()
            : TabBarView(
                controller: _tabController,
                children: [
                  _LiveTab(
                    match:      match,
                    scorecard:  _scorecard,
                    commentary: _commentary,
                    ballFlash:  _ballFlash,
                    onRefresh:  _loadInitialData,
                  ),
                  _scorecard != null
                    ? ScorecardTableWidget(scorecard: _scorecard!, match: match)
                    : const _EmptyTab(icon: Icons.scoreboard_outlined, message: 'Scorecard not available yet'),
                  _prediction != null && !_prediction!.hasError
                    ? AIPredictionWidget(prediction: _prediction!, match: match)
                    : const _EmptyTab(icon: Icons.psychology_outlined, message: 'AI analysis not available yet'),
                ],
              ),
    );
  }
}

// ── Live tab ──────────────────────────────────────────────────────────

class _LiveTab extends StatelessWidget {
  final CricketMatch    match;
  final Scorecard?      scorecard;
  final List<BallEvent> commentary;
  final bool            ballFlash;
  final Future<void> Function() onRefresh;

  const _LiveTab({
    required this.match,
    required this.scorecard,
    required this.commentary,
    required this.ballFlash,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          MatchHeaderWidget(match: match, ballFlash: ballFlash)
              .animate().fadeIn(duration: 300.ms),
          const SizedBox(height: 12),
          HeadToHeadWidget(match: match)
              .animate().fadeIn(duration: 350.ms, delay: 50.ms),
          const SizedBox(height: 12),
          if (scorecard != null && match.isLive) ...[
            LiveScoreboardWidget(
              scorecard: scorecard!,
              match:     match,
              commentary: commentary,
              ballFlash: ballFlash,
            ).animate().fadeIn(duration: 400.ms, delay: 100.ms),
            const SizedBox(height: 12),
            WormChartWidget(
              scorecard: scorecard!,
              match:     match,
            ).animate().fadeIn(duration: 450.ms, delay: 150.ms),
            const SizedBox(height: 12),
          ],
          if (commentary.isEmpty && !match.isLive)
            const _EmptyTab(icon: Icons.sports_cricket_outlined, message: 'Match has not started yet')
          else
            CommentaryFeedWidget(commentary: commentary)
                .animate().fadeIn(duration: 500.ms, delay: 200.ms),
        ],
      ),
    );
  }
}

// ── Helper widgets ────────────────────────────────────────────────────

class _ConnectionDot extends StatelessWidget {
  final SocketState state;
  const _ConnectionDot({required this.state});

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      SocketState.connected    => SGColors.good,
      SocketState.connecting   => SGColors.warn,
      SocketState.disconnected => SGColors.textMuted,
      SocketState.error        => SGColors.wicket,
    };
    final label = switch (state) {
      SocketState.connected    => 'Live',
      SocketState.connecting   => 'Connecting',
      SocketState.disconnected => 'Reconnecting',
      SocketState.error        => 'Offline',
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _ShimmerLoading extends StatelessWidget {
  const _ShimmerLoading();
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(children: [
      _shimmerBox(height: 160),
      const SizedBox(height: 12),
      _shimmerBox(height: 120),
      const SizedBox(height: 12),
      _shimmerBox(height: 200),
    ]),
  );

  Widget _shimmerBox({required double height}) => Container(
    width: double.infinity,
    height: height,
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.04),
      borderRadius: BorderRadius.circular(16),
    ),
  );
}

class _EmptyTab extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyTab({required this.icon, required this.message});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 48, color: SGColors.textMuted),
        const SizedBox(height: 16),
        Text(message, style: const TextStyle(color: SGColors.textMuted, fontSize: 14), textAlign: TextAlign.center),
      ]),
    ),
  );
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, color: SGColors.textMuted, size: 48),
          const SizedBox(height: 16),
          const Text('Could not load match', style: TextStyle(
            color: SGColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text('Check your internet connection and try again.',
            style: TextStyle(color: SGColors.textMuted, fontSize: 13), textAlign: TextAlign.center),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Retry'),
          ),
        ],
      ),
    ),
  );
}
