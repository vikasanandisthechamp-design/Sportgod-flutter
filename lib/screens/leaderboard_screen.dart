import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';

/// Global leaderboard — ranks all players by total points across three
/// time-windows: this week, this month, and all-time.
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  // Per-tab state
  final List<List<Map<String, dynamic>>> _data = [[], [], []];
  final List<bool> _loading = [true, true, true];

  // Current user's row per tab (null if not found)
  final List<Map<String, dynamic>?> _myEntry = [null, null, null];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  // ── Data loading ──────────────────────────────────────────────────────────

  Future<void> _loadAll() async {
    await Future.wait([
      _loadTab(0, _rangeForTab(0)),
      _loadTab(1, _rangeForTab(1)),
      _loadTab(2, null),
    ]);
  }

  /// Returns [start, end) UTC datetimes for week / month filters.
  (String, String)? _rangeForTab(int tab) {
    final now = DateTime.now().toUtc();
    if (tab == 0) {
      // This week (Monday 00:00 UTC → now)
      final weekday = now.weekday; // Mon=1
      final start = DateTime.utc(now.year, now.month, now.day)
          .subtract(Duration(days: weekday - 1));
      return (start.toIso8601String(), now.toIso8601String());
    } else if (tab == 1) {
      // This month (1st 00:00 UTC → now)
      final start = DateTime.utc(now.year, now.month, 1);
      return (start.toIso8601String(), now.toIso8601String());
    }
    return null;
  }

  Future<void> _loadTab(int tab, (String, String)? range) async {
    if (mounted) setState(() => _loading[tab] = true);
    try {
      final db = Supabase.instance.client;
      final uid = db.auth.currentUser?.id;

      // Build query — select from the leaderboard view / table.
      // If range is provided we filter by an `updated_at` window so the
      // backend can return weekly/monthly slices.  If the table doesn't
      // have a time column the filter is a no-op and we fall back to
      // all-time.
      var query = db
          .from('leaderboard')
          .select('display_name, avatar_url, total_points, rank, games_played, user_id');

      if (range != null) {
        query = query.gte('updated_at', range.$1).lte('updated_at', range.$2);
      }

      final res = await query
          .order('total_points', ascending: false)
          .limit(100);

      final rows = (res as List).map((e) => e as Map<String, dynamic>).toList();

      // Assign ranks based on sort order (1-indexed)
      for (var i = 0; i < rows.length; i++) {
        rows[i]['rank'] = i + 1;
      }

      // Find current user
      Map<String, dynamic>? myRow;
      if (uid != null) {
        for (final r in rows) {
          if (r['user_id'] == uid) {
            myRow = r;
            break;
          }
        }
      }

      if (mounted) {
        setState(() {
          _data[tab] = rows;
          _myEntry[tab] = myRow;
          _loading[tab] = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading[tab] = false);
    }
  }

  Future<void> _refreshTab(int tab) {
    return _loadTab(tab, tab < 2 ? _rangeForTab(tab) : null);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leaderboard'),
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [
            Tab(text: 'This Week'),
            Tab(text: 'This Month'),
            Tab(text: 'All Time'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: List.generate(3, (i) => _TabBody(
          items: _data[i],
          loading: _loading[i],
          myEntry: _myEntry[i],
          onRefresh: () => _refreshTab(i),
        )),
      ),
    );
  }
}

// ── Single tab body ──────────────────────────────────────────────────────────

class _TabBody extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final bool loading;
  final Map<String, dynamic>? myEntry;
  final Future<void> Function() onRefresh;

  const _TabBody({
    required this.items,
    required this.loading,
    required this.myEntry,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (items.isEmpty) {
      return _emptyState();
    }

    return Column(children: [
      // Top-3 podium
      if (items.length >= 3) _Podium(top3: items.sublist(0, 3)),

      // Divider
      if (items.length >= 3)
        Divider(
          height: 1,
          color: Colors.white.withValues(alpha: 0.06),
          indent: 16,
          endIndent: 16,
        ),

      // Remaining list (pull-to-refresh wraps the full scrollable)
      Expanded(
        child: RefreshIndicator(
          onRefresh: onRefresh,
          color: SGColors.primary,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: items.length > 3 ? items.length - 3 : 0,
            itemBuilder: (_, i) {
              final entry = items[i + 3];
              return _PlayerRow(entry: entry);
            },
          ),
        ),
      ),

      // Current-user bar pinned at bottom
      if (myEntry != null) _MyPositionBar(entry: myEntry!),
    ]);
  }

  Widget _emptyState() => Center(
    child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.leaderboard_rounded, size: 56, color: SGColors.textMuted.withValues(alpha: 0.5)),
        const SizedBox(height: 16),
        const Text('No rankings yet', style: TextStyle(
          fontSize: 16, fontWeight: FontWeight.w700, color: SGColors.textPrimary)),
        const SizedBox(height: 8),
        const Text(
          'Play games and earn points to climb the leaderboard.',
          style: TextStyle(fontSize: 13, color: SGColors.textMuted, height: 1.4),
          textAlign: TextAlign.center,
        ),
      ]),
    ),
  );
}

// ── Top-3 podium ────────────────────────────────────────────────────────────

class _Podium extends StatelessWidget {
  final List<Map<String, dynamic>> top3;
  const _Podium({required this.top3});

  static const _medals = [
    (color: Color(0xFFFFD700), label: '1st', icon: Icons.emoji_events_rounded),
    (color: Color(0xFFC0C0C0), label: '2nd', icon: Icons.emoji_events_rounded),
    (color: Color(0xFFCD7F32), label: '3rd', icon: Icons.emoji_events_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    // Layout: 2nd | 1st | 3rd — classic podium order
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: _podiumColumn(top3[1], 1, height: 80)),
          const SizedBox(width: 8),
          Expanded(child: _podiumColumn(top3[0], 0, height: 100)),
          const SizedBox(width: 8),
          Expanded(child: _podiumColumn(top3[2], 2, height: 68)),
        ],
      ),
    );
  }

  Widget _podiumColumn(Map<String, dynamic> entry, int idx, {required double height}) {
    final medal = _medals[idx];
    final name = entry['display_name'] as String? ?? 'Player';
    final avatar = entry['avatar_url'] as String?;
    final pts = (entry['total_points'] ?? 0) as int;
    final games = (entry['games_played'] ?? 0) as int;

    return Column(mainAxisSize: MainAxisSize.min, children: [
      // Medal icon
      Icon(medal.icon, size: idx == 0 ? 32 : 26, color: medal.color),
      const SizedBox(height: 6),

      // Avatar
      _avatar(name, avatar, radius: idx == 0 ? 30 : 24, borderColor: medal.color),
      const SizedBox(height: 8),

      // Name
      Text(
        name,
        style: const TextStyle(
          fontSize: 13, fontWeight: FontWeight.w700, color: SGColors.textPrimary,
        ),
        maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
      ),
      const SizedBox(height: 2),

      // Points
      Text(
        '$pts pts',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: medal.color),
      ),

      // Games played
      Text(
        '$games games',
        style: const TextStyle(fontSize: 10, color: SGColors.textMuted),
      ),

      const SizedBox(height: 8),

      // Podium bar
      Container(
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              medal.color.withValues(alpha: 0.25),
              medal.color.withValues(alpha: 0.08),
            ],
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
          border: Border(
            top: BorderSide(color: medal.color.withValues(alpha: 0.5), width: 2),
            left: BorderSide(color: medal.color.withValues(alpha: 0.15)),
            right: BorderSide(color: medal.color.withValues(alpha: 0.15)),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          medal.label,
          style: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w900, color: medal.color,
            letterSpacing: 0.5,
          ),
        ),
      ),
    ]);
  }
}

// ── Regular player row (rank 4+) ────────────────────────────────────────────

class _PlayerRow extends StatelessWidget {
  final Map<String, dynamic> entry;
  const _PlayerRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final rank  = entry['rank'] as int? ?? 0;
    final name  = entry['display_name'] as String? ?? 'Player';
    final avatar = entry['avatar_url'] as String?;
    final pts   = (entry['total_points'] ?? 0) as int;
    final games = (entry['games_played'] ?? 0) as int;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: SGColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(children: [
        // Rank number
        SizedBox(
          width: 32,
          child: Text(
            '#$rank',
            style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w800, color: SGColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Avatar
        _avatar(name, avatar, radius: 18),
        const SizedBox(width: 12),

        // Name + games
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600, color: SGColors.textPrimary,
            ), maxLines: 1, overflow: TextOverflow.ellipsis),
            Text('$games games', style: const TextStyle(fontSize: 11, color: SGColors.textMuted)),
          ],
        )),

        // Points
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('$pts', style: const TextStyle(
            fontSize: 16, fontWeight: FontWeight.w800, color: SGColors.textPrimary,
          )),
          const Text('pts', style: TextStyle(fontSize: 10, color: SGColors.textMuted)),
        ]),
      ]),
    );
  }
}

// ── Current user bar (fixed at bottom) ──────────────────────────────────────

class _MyPositionBar extends StatelessWidget {
  final Map<String, dynamic> entry;
  const _MyPositionBar({required this.entry});

  @override
  Widget build(BuildContext context) {
    final rank  = entry['rank'] as int? ?? 0;
    final name  = entry['display_name'] as String? ?? 'You';
    final avatar = entry['avatar_url'] as String?;
    final pts   = (entry['total_points'] ?? 0) as int;
    final games = (entry['games_played'] ?? 0) as int;

    return Container(
      decoration: BoxDecoration(
        color: SGColors.card,
        border: Border(
          top: BorderSide(color: SGColors.primary.withValues(alpha: 0.3), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        16, 12, 16, 12 + MediaQuery.of(context).padding.bottom,
      ),
      child: Row(children: [
        // Rank badge
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: SGColors.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            '#$rank',
            style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w900, color: SGColors.primary,
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Avatar
        _avatar(name, avatar, radius: 18, borderColor: SGColors.primary),
        const SizedBox(width: 10),

        // Name + label
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(name, style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w700, color: SGColors.textPrimary,
            ), maxLines: 1, overflow: TextOverflow.ellipsis),
            Text('$games games played', style: const TextStyle(fontSize: 11, color: SGColors.textMuted)),
          ],
        )),

        // Points
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('$pts', style: const TextStyle(
            fontSize: 18, fontWeight: FontWeight.w900, color: SGColors.primary,
          )),
          const Text('pts', style: TextStyle(fontSize: 10, color: SGColors.textMuted)),
        ]),
      ]),
    );
  }
}

// ── Shared avatar helper ────────────────────────────────────────────────────

Widget _avatar(String name, String? url, {double radius = 18, Color? borderColor}) {
  final letter = name.isNotEmpty ? name[0].toUpperCase() : 'U';
  final hasUrl = url != null && url.isNotEmpty;

  return Container(
    width: radius * 2,
    height: radius * 2,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: borderColor != null
          ? Border.all(color: borderColor.withValues(alpha: 0.6), width: 2)
          : null,
    ),
    child: CircleAvatar(
      radius: radius - (borderColor != null ? 2 : 0),
      backgroundColor: SGColors.primary.withValues(alpha: 0.18),
      backgroundImage: hasUrl ? NetworkImage(url) : null,
      child: hasUrl
          ? null
          : Text(
              letter,
              style: TextStyle(
                fontSize: radius * 0.7,
                fontWeight: FontWeight.w800,
                color: SGColors.primary,
              ),
            ),
    ),
  );
}
