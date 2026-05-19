import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../models/cricket_models.dart';
import '../services/api_service.dart';
import '../services/favorites_service.dart';
import '../theme/app_theme.dart';
import '../widgets/shimmer_loading.dart';
import '../widgets/team_logo_widget.dart';
import 'search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _api = ApiService();
  List<CricketMatch> _matches  = [];
  bool               _loading  = true;
  bool               _silentRefreshing = false; // background refresh — no spinner
  String?            _error;
  Timer?             _pollTimer;

  // Poll every 8s when live matches exist, 30s otherwise — mirrors web app cadence.
  static const _liveInterval   = Duration(seconds: 8);
  static const _quietInterval  = Duration(seconds: 30);

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
    _api.dispose();
    super.dispose();
  }

  /// Pause polling when the app goes to background (saves battery + quota).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _silentRefresh(); // catch up immediately
      _schedulePoll();
    } else if (state == AppLifecycleState.paused ||
               state == AppLifecycleState.detached) {
      _pollTimer?.cancel();
      _pollTimer = null;
    }
  }

  /// First load — shows full-screen spinner.
  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final matches = await _api.getLiveMatches();
      if (mounted) setState(() { _matches = matches; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
    _schedulePoll();
  }

  /// Subsequent refresh — no spinner, scores just slide in.
  Future<void> _silentRefresh() async {
    if (_silentRefreshing) return;
    _silentRefreshing = true;
    try {
      final matches = await _api.getLiveMatches();
      if (mounted) setState(() => _matches = matches);
    } catch (_) { /* network blip — keep stale data */ }
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
      appBar: AppBar(
        title: const Row(children: [
          Text('🏏 ', style: TextStyle(fontSize: 22)),
          Text('SportGod ', style: TextStyle(fontWeight: FontWeight.w800)),
          Text('AI', style: TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.w800)),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded, size: 22),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SearchScreen()),
            ),
            tooltip: 'Search',
          ),
          // Pulsing dot when silently refreshing live matches
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
              icon: const Icon(Icons.refresh, size: 22),
              onPressed: _load,
              tooltip: 'Refresh',
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
          ? const ShimmerList()
          : _error != null
            ? _ErrorView(error: _error!, onRetry: _load)
            : _matches.isEmpty
              ? const _EmptyState()
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount:  _matches.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (ctx, i) => _MatchCard(
                    match:  _matches[i],
                    onTap:  () => ctx.push('/match/${_matches[i].id}'),
                  ),
                ),
      ),
    );
  }
}

class _MatchCard extends StatefulWidget {
  final CricketMatch match;
  final VoidCallback onTap;
  const _MatchCard({required this.match, required this.onTap});

  @override
  State<_MatchCard> createState() => _MatchCardState();
}

class _MatchCardState extends State<_MatchCard> {
  static final _favService = FavoritesService();
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    _loadFavorite();
  }

  Future<void> _loadFavorite() async {
    final fav = await _favService.isFavorite(widget.match.id);
    if (mounted) setState(() => _isFavorite = fav);
  }

  Future<void> _toggleFavorite() async {
    HapticFeedback.selectionClick();
    await _favService.toggleFavorite(widget.match.id);
    if (mounted) setState(() => _isFavorite = !_isFavorite);
  }

  @override
  Widget build(BuildContext context) {
    final match = widget.match;
    final homeRuns  = match.homeRuns;
    final awayRuns  = match.awayRuns;
    final latestHome = homeRuns.lastOrNull;
    final latestAway = awayRuns.lastOrNull;

    return SGCard(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(match.matchType, style: const TextStyle(color: SGColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: _toggleFavorite,
                    child: Icon(
                      _isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      size: 18,
                      color: _isFavorite ? SGColors.live : SGColors.textMuted,
                    ),
                  ),
                  const SizedBox(width: 10),
                  _StatusBadge(status: match.status),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _TeamBlock(
                team:  match.teamHome,
                run:   latestHome,
                align: CrossAxisAlignment.start,
              )),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('vs', style: TextStyle(color: SGColors.textMuted, fontSize: 11, fontWeight: FontWeight.w700)),
                  if (latestHome != null || latestAway != null)
                    const SizedBox(height: 2),
                ]),
              ),
              Expanded(child: _TeamBlock(
                team:  match.teamAway,
                run:   latestAway,
                align: CrossAxisAlignment.end,
              )),
            ],
          ),
          if (match.note.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(match.note,
              style: const TextStyle(color: SGColors.textSecondary, fontSize: 12),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ],
      ),
    );
  }
}

class _TeamBlock extends StatelessWidget {
  final Team            team;
  final InningsRun?     run;
  final CrossAxisAlignment align;
  const _TeamBlock({required this.team, this.run, required this.align});

  @override
  Widget build(BuildContext context) {
    final isLeft = align == CrossAxisAlignment.start;
    return Column(
      crossAxisAlignment: align,
      children: [
        Row(
          mainAxisAlignment: isLeft ? MainAxisAlignment.start : MainAxisAlignment.end,
          children: [
            if (isLeft) ...[
              TeamLogoWidget(short: team.short, name: team.name, imageUrl: team.imageUrl, size: 32),
              const SizedBox(width: 8),
            ],
            Flexible(child: Text(
              team.short.isNotEmpty ? team.short : team.name,
              style: const TextStyle(color: SGColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 14),
              overflow: TextOverflow.ellipsis,
            )),
            if (!isLeft) ...[
              const SizedBox(width: 8),
              TeamLogoWidget(short: team.short, name: team.name, imageUrl: team.imageUrl, size: 32),
            ],
          ],
        ),
        if (run != null) ...[
          const SizedBox(height: 4),
          Text(
            '${run!.scoreString}  (${run!.overs})',
            style: const TextStyle(
              color: SGColors.textPrimary,
              fontSize: 19, fontWeight: FontWeight.w900,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final isLive = status == 'Live';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color:        (isLive ? SGColors.live : SGColors.textMuted).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border:       Border.all(color: (isLive ? SGColors.live : SGColors.textMuted).withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (isLive) Container(
          width: 6, height: 6,
          margin: const EdgeInsets.only(right: 5),
          decoration: const BoxDecoration(color: SGColors.live, shape: BoxShape.circle),
        ),
        Text(status, style: TextStyle(
          color:      isLive ? SGColors.live : SGColors.textMuted,
          fontSize:   10, fontWeight: FontWeight.w800,
        )),
      ]),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => const Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text('🏏', style: TextStyle(fontSize: 48)),
      SizedBox(height: 16),
      Text('No live matches right now', style: TextStyle(color: SGColors.textSecondary, fontSize: 16)),
      SizedBox(height: 6),
      Text('Pull to refresh', style: TextStyle(color: SGColors.textMuted, fontSize: 13)),
    ]),
  );
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.wifi_off, color: SGColors.wicket, size: 48),
      const SizedBox(height: 12),
      const Text('Could not load matches', style: TextStyle(color: SGColors.textSecondary)),
      const SizedBox(height: 16),
      FilledButton(onPressed: onRetry, child: const Text('Retry')),
    ]),
  );
}
