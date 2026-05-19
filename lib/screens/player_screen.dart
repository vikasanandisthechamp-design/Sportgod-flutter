import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/player_model.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class PlayerScreen extends StatefulWidget {
  final String playerId;
  final String playerName;

  const PlayerScreen({
    super.key,
    required this.playerId,
    required this.playerName,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  final _api = ApiService();

  Player?          _player;
  List<RecentForm> _recentForm = [];
  bool             _loading    = true;
  String?          _error;

  @override
  void initState() {
    super.initState();
    _loadPlayer();
  }

  Future<void> _loadPlayer() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });

    try {
      final data = await _api.getPlayer(widget.playerId);
      if (!mounted) return;
      setState(() {
        _player = Player.fromJson(data);
        final form = (data['recent_form'] ?? []) as List;
        _recentForm = form
            .map((f) => RecentForm.fromJson(f as Map<String, dynamic>))
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _player?.name ?? widget.playerName,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: _loading
          ? const _ShimmerLoading()
          : _error != null
              ? _ErrorView(error: _error!, onRetry: _loadPlayer)
              : _player == null
                  ? const _ShimmerLoading()
                  : RefreshIndicator(
                      onRefresh: _loadPlayer,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _PlayerHeader(player: _player!)
                              .animate().fadeIn(duration: 300.ms),
                          const SizedBox(height: 16),
                          _SeasonStatsCard(player: _player!)
                              .animate().fadeIn(duration: 400.ms, delay: 100.ms),
                          const SizedBox(height: 16),
                          _FantasyValueCard(player: _player!)
                              .animate().fadeIn(duration: 400.ms, delay: 150.ms),
                          if (_recentForm.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            _RecentFormSection(form: _recentForm)
                                .animate().fadeIn(duration: 500.ms, delay: 200.ms),
                          ],
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
    );
  }
}

// ── Player header ──────────────────────────────────────────────────────

class _PlayerHeader extends StatelessWidget {
  final Player player;
  const _PlayerHeader({required this.player});

  @override
  Widget build(BuildContext context) {
    return SGCard(
      child: Row(
        children: [
          // Avatar
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: SGColors.primary.withValues(alpha: 0.15),
              border: Border.all(
                color: SGColors.primary.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: player.imageUrl.isNotEmpty
                ? ClipOval(
                    child: Image.network(
                      player.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _avatarFallback(),
                    ),
                  )
                : _avatarFallback(),
          ),
          const SizedBox(width: 16),

          // Name + meta
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.name,
                  style: const TextStyle(
                    color: SGColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (player.teamShort.isNotEmpty) ...[
                      Text(
                        player.teamShort,
                        style: const TextStyle(
                          color: SGColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      _dot(),
                    ],
                    if (player.country.isNotEmpty) ...[
                      Text(
                        player.country,
                        style: const TextStyle(
                          color: SGColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                _RoleBadge(role: player.role),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarFallback() => Center(
        child: Text(
          player.name.isNotEmpty ? player.name[0].toUpperCase() : '?',
          style: const TextStyle(
            color: SGColors.primary,
            fontSize: 28,
            fontWeight: FontWeight.w800,
          ),
        ),
      );

  Widget _dot() => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 6),
        child: Text(
          '•',
          style: TextStyle(color: SGColors.textMuted, fontSize: 10),
        ),
      );
}

// ── Role badge ──────────────────────────────────────────────────────────

class _RoleBadge extends StatelessWidget {
  final String role;
  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = switch (role) {
      'BAT' => (const Color(0xFF3B82F6), Colors.white),     // Blue
      'BWL' => (const Color(0xFFEF4444), Colors.white),     // Red
      'AR'  => (const Color(0xFFA855F7), Colors.white),     // Purple
      'WK'  => (const Color(0xFF22C55E), Colors.white),     // Green
      _     => (SGColors.textMuted, Colors.white),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: bg.withValues(alpha: 0.4)),
      ),
      child: Text(
        role,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ── Season stats card ──────────────────────────────────────────────────

class _SeasonStatsCard extends StatelessWidget {
  final Player player;
  const _SeasonStatsCard({required this.player});

  @override
  Widget build(BuildContext context) {
    return SGCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Season Stats',
            style: TextStyle(
              color: SGColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _StatTile(label: 'Matches', value: '${player.matches}'),
              _StatTile(label: 'Runs', value: '${player.runs}'),
              _StatTile(label: 'Wickets', value: '${player.wickets}'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _StatTile(
                label: 'Average',
                value: player.battingAvg.toStringAsFixed(1),
              ),
              _StatTile(
                label: 'Strike Rate',
                value: player.strikeRate.toStringAsFixed(1),
                highlight: player.strikeRate >= 150,
              ),
              _StatTile(
                label: 'Economy',
                value: player.economy.toStringAsFixed(2),
                highlight: player.economy > 0 && player.economy <= 7,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final bool   highlight;

  const _StatTile({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: highlight ? SGColors.good : SGColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: SGColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Fantasy value card ──────────────────────────────────────────────────

class _FantasyValueCard extends StatelessWidget {
  final Player player;
  const _FantasyValueCard({required this.player});

  @override
  Widget build(BuildContext context) {
    final cost = player.fantasyCost;
    // Value tier: cheap < 8, mid 8-9.5, premium > 9.5
    final (String tier, Color color) = cost >= 9.5
        ? ('Premium', const Color(0xFFF59E0B))
        : cost >= 8.0
            ? ('Mid-Range', SGColors.primary)
            : ('Value Pick', SGColors.good);

    return SGCard(
      child: Row(
        children: [
          // Coin icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [color.withValues(alpha: 0.3), color.withValues(alpha: 0.1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Icon(Icons.monetization_on_rounded, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Fantasy Value',
                  style: TextStyle(
                    color: SGColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      cost.toStringAsFixed(1),
                      style: TextStyle(
                        color: color,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Cr',
                      style: TextStyle(
                        color: SGColors.textMuted,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              tier,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Recent form (horizontal scroll) ─────────────────────────────────────

class _RecentFormSection extends StatelessWidget {
  final List<RecentForm> form;
  const _RecentFormSection({required this.form});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Recent Form',
            style: TextStyle(
              color: SGColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: form.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) => _RecentFormCard(entry: form[i]),
          ),
        ),
      ],
    );
  }
}

class _RecentFormCard extends StatelessWidget {
  final RecentForm entry;
  const _RecentFormCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final isGoodBat = entry.runs >= 30;
    final isGoodBowl = entry.wickets >= 2;

    return Container(
      width: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SGColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: (isGoodBat || isGoodBowl)
              ? SGColors.good.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Opponent
          Text(
            'vs ${entry.opponent}',
            style: const TextStyle(
              color: SGColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          // Runs
          Row(
            children: [
              Text(
                '${entry.runs}',
                style: TextStyle(
                  color: isGoodBat ? SGColors.good : SGColors.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                ' (${entry.balls})',
                style: const TextStyle(
                  color: SGColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Wickets + SR
          Row(
            children: [
              if (entry.wickets > 0) ...[
                Icon(Icons.sports_cricket, size: 12, color: SGColors.wicket.withValues(alpha: 0.8)),
                const SizedBox(width: 3),
                Text(
                  '${entry.wickets}w',
                  style: const TextStyle(
                    color: SGColors.wicket,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                'SR ${entry.strikeRate.toStringAsFixed(0)}',
                style: TextStyle(
                  color: entry.strikeRate >= 150
                      ? SGColors.good
                      : SGColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Helper widgets ──────────────────────────────────────────────────────

class _ShimmerLoading extends StatelessWidget {
  const _ShimmerLoading();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _shimmerBox(height: 120),
            const SizedBox(height: 16),
            _shimmerBox(height: 160),
            const SizedBox(height: 16),
            _shimmerBox(height: 80),
            const SizedBox(height: 16),
            _shimmerBox(height: 120),
          ],
        ),
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
              const Icon(Icons.person_off_rounded,
                  color: SGColors.textMuted, size: 48),
              const SizedBox(height: 16),
              const Text(
                'Could not load player',
                style: TextStyle(
                  color: SGColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Check your internet connection and try again.',
                style: TextStyle(color: SGColors.textMuted, fontSize: 13),
                textAlign: TextAlign.center,
              ),
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
