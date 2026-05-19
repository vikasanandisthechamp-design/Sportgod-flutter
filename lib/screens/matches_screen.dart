import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';
import '../services/favorites_service.dart';
import '../models/cricket_models.dart';
import '../theme/app_theme.dart';
import '../utils/debounce.dart';
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
  final _throttle = Throttle(cooldown: Duration(seconds: 2));
  List<CricketMatch> _matches = [];
  Set<String> _favoriteIds = {};
  bool  _loading  = true;
  bool  _silentRefreshing = false;
  Timer? _pollTimer;

  String _filterType = 'all';
  String _sortBy = 'default';

  static const _liveInterval  = Duration(seconds: 8);
  static const _quietInterval = Duration(seconds: 30);

  static const _greenAccent = Color(0xFF00E5A8);

  static const _filterOptions = <String, String>{
    'all':  'All',
    't20':  'T20',
    'odi':  'ODI',
    'test': 'Test',
    'live': 'Live Only',
  };

  static const _sortOptions = <String, String>{
    'default': 'Default',
    'recent':  'Most Recent',
    'type':    'Match Type',
  };

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

  List<CricketMatch> get _filteredMatches {
    List<CricketMatch> result;
    switch (_filterType) {
      case 't20':
        result = _matches.where((m) => m.matchType.toUpperCase() == 'T20').toList();
      case 'odi':
        result = _matches.where((m) => m.matchType.toUpperCase() == 'ODI').toList();
      case 'test':
        result = _matches.where((m) => m.matchType.toUpperCase() == 'TEST').toList();
      case 'live':
        result = _matches.where((m) => m.isLive).toList();
      default:
        result = List.of(_matches);
    }

    switch (_sortBy) {
      case 'recent':
        result.sort((a, b) => b.date.compareTo(a.date));
      case 'type':
        result.sort((a, b) => a.matchType.compareTo(b.matchType));
      default:
        // Default: live first, then by date descending
        result.sort((a, b) {
          if (a.isLive && !b.isLive) return -1;
          if (!a.isLive && b.isLive) return 1;
          return b.date.compareTo(a.date);
        });
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final filtered  = _filteredMatches;
    final favorites = filtered.where((m) => _favoriteIds.contains(m.id)).toList();
    final live      = filtered.where((m) => m.isLive).toList();
    final other     = filtered.where((m) => !m.isLive).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Matches'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort_rounded, size: 22),
            tooltip: 'Sort',
            color: SGColors.card,
            onSelected: (value) => setState(() => _sortBy = value),
            itemBuilder: (_) => _sortOptions.entries.map((e) => PopupMenuItem(
              value: e.key,
              child: Row(
                children: [
                  if (_sortBy == e.key)
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: Icon(Icons.check_rounded, size: 16, color: _greenAccent),
                    )
                  else
                    const SizedBox(width: 24),
                  Text(e.value, style: TextStyle(
                    color: _sortBy == e.key ? _greenAccent : SGColors.textPrimary,
                    fontSize: 14,
                  )),
                ],
              ),
            )).toList(),
          ),
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
              onPressed: () => _throttle.call(() => _load()),
            ),
        ],
      ),
      body: _loading
          ? const ShimmerList()
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
                children: [
                  _buildFilterChips(),
                  const SizedBox(height: 12),
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
                  if (filtered.isEmpty)
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

  Widget _buildFilterChips() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _filterOptions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final entry = _filterOptions.entries.elementAt(index);
          final selected = _filterType == entry.key;
          return FilterChip(
            label: Text(entry.value),
            selected: selected,
            onSelected: (_) => setState(() => _filterType = entry.key),
            selectedColor: _greenAccent,
            backgroundColor: SGColors.card,
            checkmarkColor: SGColors.bg,
            side: BorderSide(
              color: selected ? _greenAccent : Colors.white.withValues(alpha: 0.08),
            ),
            labelStyle: TextStyle(
              color: selected ? SGColors.bg : SGColors.textSecondary,
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 4),
          );
        },
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
