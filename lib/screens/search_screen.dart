import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/cricket_models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/team_logo_widget.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _api = ApiService();
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  List<CricketMatch> _allMatches = [];
  List<CricketMatch> _results = [];
  bool _loading = true;
  bool _hasSearched = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _fetchMatches();
    // Auto-focus the search field on open.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    _api.dispose();
    super.dispose();
  }

  Future<void> _fetchMatches() async {
    try {
      final matches = await _api.getLiveMatches();
      if (mounted) {
        setState(() {
          _allMatches = matches;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _filter(query);
    });
  }

  void _filter(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() {
        _results = [];
        _hasSearched = false;
      });
      return;
    }

    final filtered = _allMatches.where((m) {
      final homeName  = m.teamHome.name.toLowerCase();
      final homeShort = m.teamHome.short.toLowerCase();
      final awayName  = m.teamAway.name.toLowerCase();
      final awayShort = m.teamAway.short.toLowerCase();
      final venue     = m.venue.toLowerCase();
      final note      = m.note.toLowerCase();
      return homeName.contains(q) ||
             homeShort.contains(q) ||
             awayName.contains(q) ||
             awayShort.contains(q) ||
             venue.contains(q) ||
             note.contains(q);
    }).toList();

    setState(() {
      _results = filtered;
      _hasSearched = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SGColors.bg,
      appBar: AppBar(
        backgroundColor: SGColors.bg,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: TextField(
          controller: _controller,
          focusNode: _focusNode,
          onChanged: _onSearchChanged,
          style: const TextStyle(color: SGColors.textPrimary, fontSize: 16),
          decoration: const InputDecoration(
            hintText: 'Search matches, teams...',
            hintStyle: TextStyle(color: SGColors.textMuted, fontSize: 16),
            border: InputBorder.none,
          ),
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 20),
              onPressed: () {
                _controller.clear();
                _filter('');  // also triggers setState
              },
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : !_hasSearched
              ? _buildIdleState()
              : _results.isEmpty
                  ? _buildEmptyState()
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _results.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (ctx, i) => _SearchResultCard(
                        match: _results[i],
                        onTap: () => ctx.push('/match/${_results[i].id}'),
                      ),
                    ),
    );
  }

  Widget _buildIdleState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_rounded, size: 48, color: SGColors.textMuted),
          SizedBox(height: 16),
          Text('Search for matches or teams',
              style: TextStyle(color: SGColors.textSecondary, fontSize: 15)),
          SizedBox(height: 6),
          Text('Type a team name, short code, or venue',
              style: TextStyle(color: SGColors.textMuted, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search_off_rounded, size: 48, color: SGColors.textMuted),
          const SizedBox(height: 16),
          const Text('No matches found',
              style: TextStyle(color: SGColors.textSecondary, fontSize: 15)),
          const SizedBox(height: 6),
          Text('"${_controller.text}" didn\'t match any results',
              style: const TextStyle(color: SGColors.textMuted, fontSize: 13)),
        ],
      ),
    );
  }
}

class _SearchResultCard extends StatelessWidget {
  final CricketMatch match;
  final VoidCallback onTap;
  const _SearchResultCard({required this.match, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final homeRuns = match.homeRuns;
    final awayRuns = match.awayRuns;
    final latestHome = homeRuns.lastOrNull;
    final latestAway = awayRuns.lastOrNull;

    return SGCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(match.matchType,
                  style: const TextStyle(
                      color: SGColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
              _StatusChip(status: match.status),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _teamCol(match.teamHome, latestHome, CrossAxisAlignment.start)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text('vs',
                    style: TextStyle(
                        color: SGColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
              Expanded(child: _teamCol(match.teamAway, latestAway, CrossAxisAlignment.end)),
            ],
          ),
          if (match.note.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(match.note,
                style: const TextStyle(color: SGColors.textSecondary, fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ],
      ),
    );
  }

  Widget _teamCol(Team team, InningsRun? run, CrossAxisAlignment align) {
    final isLeft = align == CrossAxisAlignment.start;
    return Column(
      crossAxisAlignment: align,
      children: [
        Row(
          mainAxisAlignment: isLeft ? MainAxisAlignment.start : MainAxisAlignment.end,
          children: [
            if (isLeft) ...[
              TeamLogoWidget(short: team.short, name: team.name, imageUrl: team.imageUrl, size: 28),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                team.short.isNotEmpty ? team.short : team.name,
                style: const TextStyle(
                    color: SGColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (!isLeft) ...[
              const SizedBox(width: 8),
              TeamLogoWidget(short: team.short, name: team.name, imageUrl: team.imageUrl, size: 28),
            ],
          ],
        ),
        if (run != null) ...[
          const SizedBox(height: 4),
          Text(
            '${run.scoreString}  (${run.overs})',
            style: const TextStyle(
              color: SGColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w900,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final isLive = status == 'Live';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: (isLive ? SGColors.live : SGColors.textMuted).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: (isLive ? SGColors.live : SGColors.textMuted).withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (isLive)
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(right: 5),
            decoration: const BoxDecoration(color: SGColors.live, shape: BoxShape.circle),
          ),
        Text(status,
            style: TextStyle(
              color: isLive ? SGColors.live : SGColors.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            )),
      ]),
    );
  }
}
