import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';
import '../models/cricket_models.dart';
import '../theme/app_theme.dart';
import '../widgets/shimmer_loading.dart';

class GamesScreen extends StatefulWidget {
  const GamesScreen({super.key});

  @override
  State<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends State<GamesScreen> with WidgetsBindingObserver {
  final _api = ApiService();
  List<CricketMatch> _matches = [];
  bool   _loading  = true;
  bool   _silentRefreshing = false;
  String? _error;
  Timer? _pollTimer;

  static const _liveInterval  = Duration(seconds: 8);
  static const _quietInterval = Duration(seconds: 30);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _silentRefresh();
      _schedulePoll();
    } else if (state == AppLifecycleState.paused ||
               state == AppLifecycleState.detached) {
      _pollTimer?.cancel();
      _pollTimer = null;
    }
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      _matches = await _api.getLiveMatches();
    } catch (e) {
      _error = 'Could not load matches. Check your connection.';
    }
    if (mounted) setState(() => _loading = false);
    _schedulePoll();
  }

  Future<void> _silentRefresh() async {
    if (_silentRefreshing) return;
    _silentRefreshing = true;
    try {
      final matches = await _api.getLiveMatches();
      if (mounted) setState(() => _matches = matches);
    } catch (_) {}
    _silentRefreshing = false;
  }

  void _schedulePoll() {
    _pollTimer?.cancel();
    final hasLive = _matches.any((m) => m.isLive);
    _pollTimer = Timer.periodic(
      hasLive ? _liveInterval : _quietInterval,
      (_) => _silentRefresh(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Games')),
      body: _loading
          ? const ShimmerList(itemCount: 4)
          : _error != null
              ? Center(child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.wifi_off_rounded, size: 48, color: SGColors.textMuted),
                    const SizedBox(height: 16),
                    Text(_error!, textAlign: TextAlign.center,
                        style: const TextStyle(color: SGColors.textMuted, fontSize: 14)),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF22C55E),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ]),
                ))
              : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Fantasy card
                  _gameTypeCard(
                    icon: Icons.groups_rounded,
                    title: 'Fantasy Cricket',
                    subtitle: 'Build your dream team and compete',
                    gradient: [const Color(0xFF6366F1), const Color(0xFF8B5CF6)],
                  ),
                  const SizedBox(height: 12),

                  // Predictions card
                  _gameTypeCard(
                    icon: Icons.psychology_rounded,
                    title: 'Predictions',
                    subtitle: 'Test your cricket knowledge, score points',
                    gradient: [const Color(0xFF00E5A8), const Color(0xFF00C9FF)],
                  ),
                  const SizedBox(height: 12),

                  // Anti-gambling disclaimer
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E).withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.15)),
                    ),
                    child: Row(children: [
                      Icon(Icons.volunteer_activism_rounded, size: 18, color: const Color(0xFF22C55E).withValues(alpha: 0.8)),
                      const SizedBox(width: 10),
                      Expanded(child: Text(
                        'Points-only platform. No real money. We promote skill-based sports engagement, not gambling.',
                        style: TextStyle(fontSize: 11, color: const Color(0xFF22C55E).withValues(alpha: 0.9), height: 1.4),
                      )),
                    ]),
                  ),
                  const SizedBox(height: 24),

                  // Match picker
                  const Text('SELECT A MATCH', style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w800,
                    color: SGColors.textMuted, letterSpacing: 1.2,
                  )),
                  const SizedBox(height: 10),

                  if (_matches.isEmpty)
                    _emptyState()
                  else
                    ..._matches.map(_matchEntry),
                ],
              ),
            ),
    );
  }

  Widget _gameTypeCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> gradient,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(children: [
        Icon(icon, size: 36, color: Colors.white),
        const SizedBox(width: 16),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white)),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.8))),
          ],
        )),
      ]),
    );
  }

  Widget _matchEntry(CricketMatch m) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: SGColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Row(children: [
            if (m.isLive)
              Container(
                width: 6, height: 6, margin: const EdgeInsets.only(right: 8),
                decoration: const BoxDecoration(color: SGColors.live, shape: BoxShape.circle),
              ),
            Text('${m.teamHome.short} vs ${m.teamAway.short}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: SGColors.textPrimary)),
            const Spacer(),
            Text(m.matchType, style: const TextStyle(fontSize: 11, color: SGColors.textMuted)),
          ]),
        ),
        Divider(color: Colors.white.withValues(alpha: 0.06), height: 1),
        Row(children: [
          Expanded(
            child: TextButton.icon(
              onPressed: () => context.push('/fantasy/build/${m.id}'),
              icon: const Icon(Icons.groups_rounded, size: 16),
              label: const Text('Fantasy', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(foregroundColor: const Color(0xFF6366F1)),
            ),
          ),
          Container(width: 1, height: 28, color: Colors.white.withValues(alpha: 0.06)),
          Expanded(
            child: TextButton.icon(
              onPressed: () => context.push('/predict/${m.id}'),
              icon: const Icon(Icons.psychology_rounded, size: 16),
              label: const Text('Predict', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(foregroundColor: const Color(0xFF00E5A8)),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _emptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: Column(children: [
          Icon(Icons.sports_cricket_outlined, size: 48, color: SGColors.textMuted),
          SizedBox(height: 12),
          Text('No matches available', style: TextStyle(color: SGColors.textMuted)),
        ]),
      ),
    );
  }
}
