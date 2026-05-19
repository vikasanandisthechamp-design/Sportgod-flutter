import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/contest_models.dart';
import '../../services/contest_service.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shimmer_loading.dart';

class ContestsScreen extends StatefulWidget {
  final String matchId;
  final String? teamCode;
  final String? matchName;
  final int initialTab;

  const ContestsScreen({
    super.key,
    required this.matchId,
    this.teamCode,
    this.matchName,
    this.initialTab = 0,
  });

  @override
  State<ContestsScreen> createState() => _ContestsScreenState();
}

class _ContestsScreenState extends State<ContestsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  late ContestService _service;
  List<Contest> _contests = [];
  bool _loading = true;
  bool _joining = false;
  final _joinCodeCtrl = TextEditingController();
  Map<String, dynamic>? _createdContest;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this, initialIndex: widget.initialTab);
    final token = context.read<AuthProvider>().accessToken;
    _service = ContestService(token: token);
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _joinCodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _contests = await _service.getContests(widget.matchId);
    if (mounted) setState(() => _loading = false);
  }

  List<Contest> get _publicContests =>
      _contests.where((c) => c.isPublic).toList();
  List<Contest> get _privateContests =>
      _contests.where((c) => !c.isPublic).toList();

  Future<void> _joinContest(Contest contest) async {
    if (widget.teamCode == null || widget.teamCode!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Build a fantasy team first to join contests')),
      );
      return;
    }
    setState(() => _joining = true);
    final result = await _service.joinContest(
      contestId: contest.id,
      teamCode: widget.teamCode!,
    );
    if (mounted) {
      setState(() => _joining = false);
      if (result['ok'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Joined contest!')),
        );
        _load();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['error'] ?? 'Failed to join')),
        );
      }
    }
  }

  Future<void> _joinByCode() async {
    final code = _joinCodeCtrl.text.trim().toUpperCase();
    if (code.isEmpty) return;

    if (widget.teamCode == null || widget.teamCode!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Build a fantasy team first to join contests')),
      );
      return;
    }

    setState(() => _joining = true);
    final result = await _service.joinContest(
      inviteCode: code,
      teamCode: widget.teamCode!,
    );
    if (mounted) {
      setState(() => _joining = false);
      if (result['ok'] == true) {
        _joinCodeCtrl.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Joined private game!')),
        );
        _load();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['error'] ?? 'Invalid code')),
        );
      }
    }
  }

  void _showCreateDialog() {
    final titleCtrl = TextEditingController();
    int entryFee = 0;
    int maxPlayers = 50;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: SGColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Create Private Game',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: SGColors.textPrimary)),
              const SizedBox(height: 4),
              const Text('Invite friends to compete in your exclusive contest',
                  style: TextStyle(fontSize: 13, color: SGColors.textMuted)),
              const SizedBox(height: 20),

              // Title
              const Text('GAME TITLE (optional)',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: SGColors.textMuted,
                      letterSpacing: 0.8)),
              const SizedBox(height: 6),
              TextField(
                controller: titleCtrl,
                style: const TextStyle(color: SGColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'My Cricket Squad Challenge',
                  hintStyle: const TextStyle(color: SGColors.textMuted),
                  filled: true,
                  fillColor: SGColors.bg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white12),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Entry fee
              const Text('ENTRY FEE (SG Points, 0 = free)',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: SGColors.textMuted,
                      letterSpacing: 0.8)),
              const SizedBox(height: 6),
              TextField(
                keyboardType: TextInputType.number,
                style: const TextStyle(color: SGColors.textPrimary),
                onChanged: (v) => entryFee = int.tryParse(v) ?? 0,
                decoration: InputDecoration(
                  hintText: '0',
                  hintStyle: const TextStyle(color: SGColors.textMuted),
                  filled: true,
                  fillColor: SGColors.bg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white12),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Max players
              const Text('MAX PLAYERS',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: SGColors.textMuted,
                      letterSpacing: 0.8)),
              const SizedBox(height: 8),
              Row(
                children: [10, 25, 50, 100].map((n) {
                  final selected = maxPlayers == n;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: GestureDetector(
                        onTap: () => setSheetState(() => maxPlayers = n),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: selected
                                ? const Color(0xFFA78BFA)
                                : SGColors.bg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: selected
                                  ? const Color(0xFFA78BFA)
                                  : Colors.white12,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text('$n',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: selected
                                    ? Colors.black
                                    : SGColors.textSecondary,
                              )),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Create button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _createPrivateGame(
                      title: titleCtrl.text.isEmpty ? null : titleCtrl.text,
                      entryFee: entryFee,
                      maxPlayers: maxPlayers,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFA78BFA),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    textStyle: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                  child: const Text('CREATE GAME'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createPrivateGame({
    String? title,
    int entryFee = 0,
    int maxPlayers = 50,
  }) async {
    setState(() => _loading = true);
    final result = await _service.createContest(
      matchId: widget.matchId,
      contestType: 'private',
      title: title,
      matchName: widget.matchName,
      entryFee: entryFee,
      maxPlayers: maxPlayers,
    );

    if (mounted) {
      if (result['ok'] == true) {
        setState(() {
          _createdContest = result['contest'] as Map<String, dynamic>?;
          _loading = false;
        });
        _load();
      } else {
        setState(() => _loading = false);
        final error = result['error'] ?? result['message'] ?? 'Failed';
        if (error == 'NOT_PARTNER' || error == 'PARTNER_PENDING') {
          _showPartnerPrompt(result['message'] ?? 'Become a partner first');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error.toString())),
          );
        }
      }
    }
  }

  void _showPartnerPrompt(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SGColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Become a Partner',
            style: TextStyle(
                fontWeight: FontWeight.w800, color: SGColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message,
                style:
                    const TextStyle(fontSize: 14, color: SGColors.textSecondary)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.push('/partner');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFA78BFA),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('APPLY NOW',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contests'),
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [
            Tab(text: 'PUBLIC'),
            Tab(text: 'PRIVATE'),
          ],
          labelStyle:
              const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.8),
          indicatorColor: SGColors.primary,
        ),
      ),
      body: _loading
          ? const ShimmerList(itemCount: 4)
          : TabBarView(
              controller: _tabCtrl,
              children: [
                // Public tab
                _buildContestList(_publicContests, isPublic: true),
                // Private tab
                _buildPrivateTab(),
              ],
            ),
    );
  }

  Widget _buildPrivateTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Actions row
        Row(children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _showCreateDialog,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('CREATE',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFA78BFA),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _joinCodeCtrl,
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(
                      color: SGColors.textPrimary,
                      fontFamily: 'monospace',
                      letterSpacing: 2),
                  decoration: const InputDecoration(
                    hintText: 'CODE',
                    hintStyle: TextStyle(color: SGColors.textMuted),
                    filled: true,
                    fillColor: SGColors.bg,
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 12, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.horizontal(
                          left: Radius.circular(12)),
                      borderSide: BorderSide(color: Colors.white12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.horizontal(
                          left: Radius.circular(12)),
                      borderSide: BorderSide(color: Colors.white12),
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _joining ? null : _joinByCode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5B8CFF),
                    foregroundColor: Colors.black,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.horizontal(
                          right: Radius.circular(12)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  child: const Text('JOIN',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
          ),
        ]),
        const SizedBox(height: 16),

        // Created game card
        if (_createdContest != null) ...[
          _createdGameCard(_createdContest!),
          const SizedBox(height: 16),
        ],

        // Private contest list
        ..._buildContestCards(_privateContests),

        if (_privateContests.isEmpty && _createdContest == null)
          _emptyState('No private games yet. Create one or enter an invite code.'),
      ],
    );
  }

  Widget _createdGameCard(Map<String, dynamic> contest) {
    final code = contest['inviteCode'] ?? contest['contestCode'] ?? '';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFA78BFA).withValues(alpha: 0.15),
            const Color(0xFF5B8CFF).withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFA78BFA).withValues(alpha: 0.3)),
      ),
      child: Column(children: [
        const Text('🎉', style: TextStyle(fontSize: 36)),
        const SizedBox(height: 8),
        const Text('Game Created!',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: SGColors.textPrimary)),
        const SizedBox(height: 4),
        const Text('Share the invite code with friends',
            style: TextStyle(fontSize: 13, color: SGColors.textMuted)),
        const SizedBox(height: 16),

        // Invite code display
        Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          decoration: BoxDecoration(
            color: SGColors.bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(children: [
            const Text('INVITE CODE',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: SGColors.textMuted,
                    letterSpacing: 0.8)),
            const SizedBox(height: 4),
            Text(code,
                style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFA78BFA),
                    letterSpacing: 4,
                    fontFamily: 'monospace')),
          ]),
        ),
        const SizedBox(height: 12),

        Row(children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: code));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Code copied!')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFA78BFA),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('COPY CODE',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                final link = contest['inviteLink'] ?? '';
                if (link.isNotEmpty) {
                  Clipboard.setData(ClipboardData(text: link));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Link copied!')),
                  );
                }
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFA78BFA),
                side: const BorderSide(color: Color(0xFFA78BFA)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('COPY LINK',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _buildContestList(List<Contest> contests, {bool isPublic = true}) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (contests.isEmpty) _emptyState(
            isPublic
                ? 'No public contests yet for this match.'
                : 'No private games. Create one or enter a code.',
          ),
          ..._buildContestCards(contests),

          // Anti-gambling disclaimer
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF22C55E).withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.15)),
            ),
            child: const Text(
              'Points-only game. No real money involved. All prizes are virtual SG Points. Play responsibly!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: SGColors.textMuted, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildContestCards(List<Contest> contests) {
    return contests.map((c) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _contestCard(c),
    )).toList();
  }

  Widget _contestCard(Contest c) {
    final accent = c.isPublic ? const Color(0xFF8eff71) : const Color(0xFFA78BFA);
    return Container(
      decoration: BoxDecoration(
        color: SGColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: c.joined ? accent.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Accent line
          Container(
            height: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: c.isPublic
                  ? [const Color(0xFF8eff71), const Color(0xFF00E5A8)]
                  : [const Color(0xFFA78BFA), const Color(0xFF5B8CFF)]),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Text(
                      c.isPublic ? '🌐 PUBLIC' : '🔒 PRIVATE',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: accent,
                          letterSpacing: 0.8),
                    ),
                    if (c.joined) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text('JOINED',
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: accent)),
                      ),
                    ],
                    const Spacer(),
                    if (c.entryFee > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD700).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.2)),
                        ),
                        child: Text('${c.entryFee} PTS',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFFFD700))),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(c.title,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: SGColors.textPrimary)),
                const SizedBox(height: 12),

                // Stats row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _statCol('PLAYERS', '${c.playerCount}/${c.maxPlayers}'),
                    _statCol('POOL', '${c.entryFee * c.playerCount} PTS'),
                    _statCol('SPOTS', '${c.spotsLeft}',
                        alert: c.spotsLeft < 10),
                  ],
                ),
                const SizedBox(height: 12),

                // Fill bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: c.fillPct / 100,
                    backgroundColor: Colors.white.withValues(alpha: 0.06),
                    valueColor: AlwaysStoppedAnimation(
                        c.fillPct > 80 ? SGColors.live : accent),
                    minHeight: 4,
                  ),
                ),
                const SizedBox(height: 14),

                // Action
                if (!c.joined)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: c.isFull || _joining
                          ? null
                          : () => _joinContest(c),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: c.isFull ? SGColors.textMuted : accent,
                        foregroundColor: Colors.black,
                        disabledBackgroundColor: SGColors.textMuted,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        c.isFull
                            ? 'FULL'
                            : _joining
                                ? 'JOINING...'
                                : c.entryFee > 0
                                    ? 'JOIN · ${c.entryFee} PTS'
                                    : 'JOIN FREE',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5),
                      ),
                    ),
                  ),
                if (c.joined)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => _showLeaderboard(c),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: accent,
                        side: BorderSide(color: accent),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('VIEW LEADERBOARD →',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13)),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Leaderboard bottom sheet ──────────────────────────────────────────────

  Future<void> _showLeaderboard(Contest contest) async {
    // Show sheet immediately with a loading spinner, then fill with data
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: SGColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _LeaderboardSheet(
        contestId: contest.id,
        contestTitle: contest.title.isNotEmpty ? contest.title : '${contest.homeTeam} vs ${contest.awayTeam}',
        prizePool: contest.prizePool,
        service: _service,
      ),
    );
  }

  Widget _statCol(String label, String value, {bool alert = false}) {
    return Column(children: [
      Text(label,
          style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: SGColors.textMuted,
              letterSpacing: 0.8)),
      const SizedBox(height: 2),
      Text(value,
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: alert ? SGColors.live : SGColors.textPrimary)),
    ]);
  }

  Widget _emptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        child: Column(children: [
          const Text('🏏', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 12),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: SGColors.textMuted)),
        ]),
      ),
    );
  }
}

// ── Leaderboard bottom sheet widget ──────────────────────────────────────────

class _LeaderboardSheet extends StatefulWidget {
  final String contestId;
  final String contestTitle;
  final int prizePool;
  final ContestService service;

  const _LeaderboardSheet({
    required this.contestId,
    required this.contestTitle,
    required this.prizePool,
    required this.service,
  });

  @override
  State<_LeaderboardSheet> createState() => _LeaderboardSheetState();
}

class _LeaderboardSheetState extends State<_LeaderboardSheet> {
  List<Map<String, dynamic>> _entries = [];
  Map<String, dynamic>? _myEntry;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await widget.service.getLeaderboard(contestId: widget.contestId);
      if (!mounted) return;
      final lb = (data['leaderboard'] ?? []) as List;
      setState(() {
        _entries  = lb.map((e) => e as Map<String, dynamic>).toList();
        _myEntry  = data['myEntry'] as Map<String, dynamic>?;
        _loading  = false;
      });
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = 'Could not load leaderboard'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    const accent = SGColors.primary;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (_, scrollCtrl) => Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: SGColors.textMuted.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.contestTitle,
                      style: const TextStyle(
                        color: SGColors.textPrimary,
                        fontSize: 15, fontWeight: FontWeight.w700),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (widget.prizePool > 0)
                      Text('Prize pool: ${widget.prizePool} pts',
                        style: const TextStyle(color: accent, fontSize: 12)),
                  ],
                )),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  color: SGColors.textMuted,
                  onPressed: _load,
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white12),
          // Column headers
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                SizedBox(width: 36,
                  child: Text('#', style: TextStyle(color: SGColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600))),
                Expanded(child: Text('Team',
                  style: TextStyle(color: SGColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600))),
                Text('PTS',
                  style: TextStyle(color: SGColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          // Body
          Expanded(
            child: _loading
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
              : _error != null
                ? Center(child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.cloud_off_rounded, color: SGColors.textMuted, size: 32),
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(color: SGColors.textMuted, fontSize: 13)),
                      const SizedBox(height: 12),
                      TextButton(onPressed: _load, child: const Text('Retry')),
                    ]),
                  ))
                : _entries.isEmpty
                  ? const Center(child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('No entries yet',
                        style: TextStyle(color: SGColors.textMuted, fontSize: 14)),
                    ))
                  : ListView.separated(
                      controller: scrollCtrl,
                      itemCount: _entries.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, indent: 20, endIndent: 20, color: Colors.white10),
                      itemBuilder: (_, i) {
                        final e     = _entries[i];
                        final rank  = (e['rank'] as int?) ?? (i + 1);
                        final name  = (e['user_name'] ?? e['team_name'] ?? 'Player') as String;
                        final team  = (e['team_name'] ?? '') as String;
                        final pts   = (e['total_pts'] ?? e['totalPts'] ?? 0) as num;
                        final prize = (e['prize_won'] ?? 0) as num;
                        final isMine = _myEntry != null &&
                            e['user_id'] == _myEntry!['user_id'];

                        // Rank badge color
                        final rankColor = rank == 1
                          ? const Color(0xFFFFD700)   // gold
                          : rank == 2
                            ? const Color(0xFFC0C0C0) // silver
                            : rank == 3
                              ? const Color(0xFFCD7F32) // bronze
                              : SGColors.textMuted;

                        return Container(
                          color: isMine
                            ? accent.withValues(alpha: 0.07)
                            : Colors.transparent,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          child: Row(
                            children: [
                              // Rank
                              SizedBox(
                                width: 36,
                                child: Text('$rank',
                                  style: TextStyle(
                                    color: rankColor,
                                    fontSize: rank <= 3 ? 14 : 13,
                                    fontWeight: FontWeight.w700)),
                              ),
                              // Names
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(children: [
                                      Flexible(child: Text(name,
                                        style: TextStyle(
                                          color: isMine ? accent : SGColors.textPrimary,
                                          fontSize: 13, fontWeight: FontWeight.w600),
                                        maxLines: 1, overflow: TextOverflow.ellipsis)),
                                      if (isMine) ...[
                                        const SizedBox(width: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: accent.withValues(alpha: 0.18),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text('YOU', style: TextStyle(
                                            color: accent, fontSize: 9, fontWeight: FontWeight.w800)),
                                        ),
                                      ],
                                    ]),
                                    if (team.isNotEmpty && team != name)
                                      Text(team,
                                        style: const TextStyle(color: SGColors.textMuted, fontSize: 11),
                                        maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              ),
                              // Points + prize
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('$pts',
                                    style: const TextStyle(
                                      color: SGColors.textPrimary,
                                      fontSize: 14, fontWeight: FontWeight.w700)),
                                  if (prize > 0)
                                    Text('+$prize pts',
                                      style: const TextStyle(color: SGColors.good, fontSize: 11)),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
