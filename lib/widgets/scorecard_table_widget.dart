import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/cricket_models.dart';
import '../theme/app_theme.dart';

class ScorecardTableWidget extends StatefulWidget {
  final Scorecard      scorecard;
  final CricketMatch   match;
  const ScorecardTableWidget({super.key, required this.scorecard, required this.match});

  @override
  State<ScorecardTableWidget> createState() => _ScorecardTableWidgetState();
}

class _ScorecardTableWidgetState extends State<ScorecardTableWidget> {
  String _activeInning = 'S1';
  int    _tab          = 0;

  List<String> get _innings {
    final keys = ['S1', 'S2', 'S3', 'S4'];
    return keys.where((s) =>
      widget.scorecard.batting.any((b) => b.inning == s) ||
      widget.scorecard.bowling.any((b) => b.inning == s)
    ).toList();
  }

  String _inningLabel(String s) {
    final num = int.tryParse(s.replaceAll('S', '')) ?? 1;
    final r   = widget.scorecard.runs.where((r) => r.inning == num).firstOrNull;
    if (r == null) return s;
    final team = r.teamId == widget.match.teamHome.id
        ? widget.match.teamHome : widget.match.teamAway;
    return '${team.short} ${r.scoreString}';
  }

  @override
  Widget build(BuildContext context) {
    final batting = widget.scorecard.batting.where((b) => b.inning == _activeInning).toList();
    final bowling = widget.scorecard.bowling.where((b) => b.inning == _activeInning).toList();

    return Column(
      children: [
        // ── Innings chips ─────────────────────────────────────
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: _innings.map((s) {
              final active = s == _activeInning;
              return GestureDetector(
                onTap: () => setState(() => _activeInning = s),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color:        active ? SGColors.primary : SGColors.card,
                    borderRadius: BorderRadius.circular(20),
                    border:       Border.all(
                      color: active ? SGColors.primary : Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Text(
                    _inningLabel(s),
                    style: TextStyle(
                      color:      active ? Colors.white : SGColors.textSecondary,
                      fontSize:   12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        // ── Batting/Bowling toggle ─────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _ToggleBtn(label: 'Batting',  active: _tab == 0, onTap: () => setState(() => _tab = 0)),
              const SizedBox(width: 8),
              _ToggleBtn(label: 'Bowling', active: _tab == 1, onTap: () => setState(() => _tab = 1)),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // ── Table ─────────────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _tab == 0
                ? _BattingTable(rows: batting)
                : _BowlingTable(rows: bowling),
          ),
        ),
      ],
    );
  }
}

class _ToggleBtn extends StatelessWidget {
  final String   label;
  final bool     active;
  final VoidCallback onTap;
  const _ToggleBtn({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color:        active ? SGColors.primary.withValues(alpha: 0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border:       Border(bottom: BorderSide(
          color:  active ? SGColors.primary : Colors.transparent,
          width:  2,
        )),
      ),
      child: Text(label, style: TextStyle(
        color:      active ? SGColors.primary : SGColors.textMuted,
        fontWeight: FontWeight.w600,
        fontSize:   14,
      )),
    ),
  );
}

class _BattingTable extends StatelessWidget {
  final List<BattingRow> rows;
  const _BattingTable({required this.rows});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Center(
      child: Padding(padding: EdgeInsets.all(40),
        child: Text('No batting data', style: TextStyle(color: SGColors.textMuted))),
    );
    }

    return SGCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          const _HeaderRow(cols: ['Batter', 'R', 'B', '4s', '6s', 'SR']),
          ...rows.asMap().entries.map((e) => _BattingRow(row: e.value, alt: e.key.isOdd)),
        ],
      ),
    );
  }
}

class _BowlingTable extends StatelessWidget {
  final List<BowlingRow> rows;
  const _BowlingTable({required this.rows});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Center(
      child: Padding(padding: EdgeInsets.all(40),
        child: Text('No bowling data', style: TextStyle(color: SGColors.textMuted))),
    );
    }

    return SGCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          const _HeaderRow(cols: ['Bowler', 'O', 'M', 'R', 'W', 'Eco']),
          ...rows.asMap().entries.map((e) => _BowlingRow(row: e.value, alt: e.key.isOdd)),
        ],
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  final List<String> cols;
  const _HeaderRow({required this.cols});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color:        Colors.white.withValues(alpha: 0.04),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
    ),
    child: Row(
      children: [
        Expanded(child: Text(cols[0], style: const TextStyle(color: SGColors.textMuted, fontSize: 11, fontWeight: FontWeight.w700))),
        ...cols.skip(1).map((c) => SizedBox(
          width: 38,
          child: Text(c, textAlign: TextAlign.right,
            style: const TextStyle(color: SGColors.textMuted, fontSize: 11, fontWeight: FontWeight.w700)),
        )),
      ],
    ),
  );
}

class _BattingRow extends StatelessWidget {
  final BattingRow row;
  final bool       alt;
  const _BattingRow({required this.row, required this.alt});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    color: alt ? Colors.white.withValues(alpha: 0.02) : Colors.transparent,
    child: Row(
      children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Flexible(child: GestureDetector(
              onTap: () {
                if (row.playerId.isNotEmpty) {
                  context.push('/player/${row.playerId}?name=${Uri.encodeComponent(row.playerName)}');
                }
              },
              child: Text(row.playerName, style: const TextStyle(color: SGColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500, decoration: TextDecoration.underline, decorationColor: SGColors.textMuted, decorationStyle: TextDecorationStyle.dotted), overflow: TextOverflow.ellipsis),
            )),
            if (row.isNotOut) const Text(' *', style: TextStyle(color: SGColors.good, fontSize: 12, fontWeight: FontWeight.w700)),
          ]),
          Text(row.howOut, style: const TextStyle(color: SGColors.textMuted, fontSize: 11), overflow: TextOverflow.ellipsis),
        ])),
        _Cell('${row.runs}', bold: true),
        _Cell('${row.balls}'),
        _Cell('${row.fours}'),
        _Cell('${row.sixes}'),
        _Cell(row.strikeRate.toStringAsFixed(1),
          color: row.strikeRate >= 150 ? SGColors.good : row.strikeRate < 80 ? SGColors.wicket : null),
      ],
    ),
  );
}

class _BowlingRow extends StatelessWidget {
  final BowlingRow row;
  final bool       alt;
  const _BowlingRow({required this.row, required this.alt});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    color: alt ? Colors.white.withValues(alpha: 0.02) : Colors.transparent,
    child: Row(
      children: [
        Expanded(child: GestureDetector(
          onTap: () {
            if (row.playerId.isNotEmpty) {
              context.push('/player/${row.playerId}?name=${Uri.encodeComponent(row.playerName)}');
            }
          },
          child: Text(row.playerName, style: const TextStyle(color: SGColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500, decoration: TextDecoration.underline, decorationColor: SGColors.textMuted, decorationStyle: TextDecorationStyle.dotted), overflow: TextOverflow.ellipsis),
        )),
        _Cell('${row.overs}'),
        _Cell('${row.maidens}'),
        _Cell('${row.runs}'),
        _Cell('${row.wickets}', bold: true, color: row.wickets >= 3 ? SGColors.wicket : null),
        _Cell(row.economy.toStringAsFixed(2),
          color: row.economy <= 7 ? SGColors.good : row.economy >= 12 ? SGColors.wicket : null),
      ],
    ),
  );
}

class _Cell extends StatelessWidget {
  final String text;
  final bool   bold;
  final Color? color;
  const _Cell(this.text, {this.bold = false, this.color});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 38,
    child: Text(
      text,
      textAlign: TextAlign.right,
      style: TextStyle(
        color:      color ?? SGColors.textSecondary,
        fontSize:   13,
        fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    ),
  );
}
