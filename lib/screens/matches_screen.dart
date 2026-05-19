import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';
import '../services/favorites_service.dart';
import '../models/cricket_models.dart';
import '../theme/app_theme.dart';
import '../widgets/shimmer_loading.dart';
import '../widgets/team_logo_widget.dart';

class MatchesScreen extends StatefulWidget {
  const MatchesScreen({super.key});

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen> with WidgetsBindingObserver {
  final _api = ApiService();
  final _favService = FavoritesService();
  List<CricketMatch> _matches = [];
  Set<String> _favoriteIds = {};
  bool  _loading  = true;
  bool  _silentRefreshing = false;
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
    setState(() => _loading = true);
    try {
      _matches = await _api.getLiveMatches();
    } catch (_) {}
    await _loadFavorites();
    if (mounted) setState(() => _loading = false);
    _schedulePoll();
  }

  Future<void> _loadFavorites() async {
    try {
      final ids = await _favService.getFavorites();
      if (mounted) setState(() => _favoriteIds = ids.toSet());
    } catch (_) {}
  }

  Future<void> _silentRefresh() async {
    if (_silentRefreshing) return;
    _silentRefreshing = true;
    try {
      final matches = await _api.getLiveMatches();
      final ids = await _favService.getFavorites();
      if (mounted) {
        setState(() {
          _matches = matches;
          _favoriteIds = ids.toSet();
        });
      }
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
    final favorites = _matches.where((m) => _favoriteIds.contains(m.id)).toList();
    final live  = _matches.where((m) => m.isLive).toList();
    final other = _matches.where((m) => !m.isLive).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Matches'),
        actions: [
          if (_silentRefreshing)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: SGColors.live),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 22),
              onPressed: _load,
            ),
        ],
      ),
      body: _loading
          ? const ShimmerList()
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (favorites.isNotEmpty) ...[
                    _sectionHeader('FAVORITES', SGColors.warn),
                    const SizedBox(height: 8),
                    ...favorites.map(_matchCard),
                    const SizedBox(height: 20),
                  ],
                  if (live.isNotEmpty) ...[
                    _sectionHeader('LIVE', SGColors.live),
                    const SizedBox(height: 8),
                    ...live.map(_matchCard),
                    const SizedBox(height: 20),
                  ],
                  if (other.isNotEmpty) ...[
                    _sectionHeader('UPCOMING & RECENT', SGColors.textMuted),
                    const SizedBox(height: 8),
                    ...other.map(_matchCard),
                  ],
                  if (_matches.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: Text('No matches found',
                          style: TextStyle(color: SGColors.textMuted)),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _sectionHeader(String title, Color color) {
    return Row(children: [
      Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 8),
      Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color, letterSpacing: 1.2)),
    ]);
  }

  Widget _matchCard(CricketMatch m) {
    return GestureDetector(
      onTap: () => context.push('/match/${m.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: SGColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: _teamRow(m.teamHome, m.homeRuns)),
                const SizedBox(width: 12),
                Expanded(child: _teamRow(m.teamAway, m.awayRuns)),
              ],
            ),
            if (m.note.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(m.note, style: TextStyle(
                fontSize: 12,
                color: m.isLive ? SGColors.live : SGColors.textMuted,
              )),
            ],
            const SizedBox(height: 6),
            Row(
              children: [
                if (m.isLive)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: SGColors.live.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('LIVE', style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w800, color: SGColors.live,
                    )),
                  ),
                const Spacer(),
                Text(m.matchType, style: const TextStyle(fontSize: 11, color: SGColors.textMuted)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _teamRow(Team team, List<InningsRun> runs) {
    final latest = runs.isNotEmpty ? runs.last : null;
    return Row(
      children: [
        TeamLogoWidget(short: team.short, name: team.name, imageUrl: team.imageUrl, size: 28),
        const SizedBox(width: 8),
        Text(team.short.isNotEmpty ? team.short : team.name,
          style: const TextStyle(
            fontSize: 14, fontWeight: FontWeight.w800, color: SGColors.textPrimary,
          )),
        const Spacer(),
        if (latest != null)
          Text(latest.scoreString, style: const TextStyle(
            fontSize: 16, fontWeight: FontWeight.w800, color: SGColors.textPrimary,
          )),
        if (latest != null) ...[
          const SizedBox(width: 6),
          Text(latest.oversString, style: const TextStyle(
            fontSize: 11, color: SGColors.textMuted,
          )),
        ],
      ],
    );
  }
}
