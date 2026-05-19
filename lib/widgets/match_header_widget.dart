import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/cricket_models.dart';
import '../theme/app_theme.dart';

class MatchHeaderWidget extends StatelessWidget {
  final CricketMatch match;
  final bool         ballFlash;

  const MatchHeaderWidget({
    super.key,
    required this.match,
    required this.ballFlash,
  });

  @override
  Widget build(BuildContext context) {
    final homeRuns = match.runsFor(match.teamHome.id);
    final awayRuns = match.runsFor(match.teamAway.id);

    return Semantics(
      label: 'Match between ${match.teamHome.name} and ${match.teamAway.name}, ${match.status}',
      child: AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color:        SGColors.card,
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(
          color: ballFlash
              ? SGColors.good.withValues(alpha: 0.7)
              : Colors.white.withValues(alpha: 0.08),
          width: ballFlash ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          // ── Top bar ─────────────────────────────────────────
          _TopBar(match: match),
          const Divider(height: 1),

          // ── Score row ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Row(
              children: [
                Expanded(child: _TeamScore(team: match.teamHome, innings: homeRuns, align: TextAlign.left)),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('vs', style: TextStyle(color: SGColors.textMuted, fontWeight: FontWeight.w700)),
                ),
                Expanded(child: _TeamScore(team: match.teamAway, innings: awayRuns, align: TextAlign.right)),
              ],
            ),
          ),

          // ── Match note ───────────────────────────────────────
          if (match.note.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
              child: Text(
                match.note,
                style: const TextStyle(color: SGColors.textSecondary, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),

          // ── Venue ────────────────────────────────────────────
          if (match.venue.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
              ),
              child: Text(
                match.venue,
                style: const TextStyle(color: SGColors.textMuted, fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final CricketMatch match;
  const _TopBar({required this.match});

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    switch (match.status) {
      case 'Live':         statusColor = SGColors.live; break;
      case 'Finished':     statusColor = SGColors.textMuted; break;
      case 'Inning Break': statusColor = SGColors.warn; break;
      default:             statusColor = SGColors.textMuted;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            match.matchType,
            style: const TextStyle(color: SGColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color:        statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border:       Border.all(color: statusColor.withValues(alpha: 0.3)),
            ),
            child: Text(
              match.status,
              style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamScore extends StatelessWidget {
  final Team            team;
  final List<InningsRun> innings;
  final TextAlign       align;

  const _TeamScore({
    required this.team,
    required this.innings,
    required this.align,
  });

  @override
  Widget build(BuildContext context) {
    final isRight = align == TextAlign.right;

    return Column(
      crossAxisAlignment: isRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: isRight ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            if (!isRight) _logo(),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                team.short.isNotEmpty ? team.short : team.name,
                style: const TextStyle(
                  color:      SGColors.textPrimary,
                  fontSize:   14,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isRight) ...[const SizedBox(width: 8), _logo()],
          ],
        ),
        const SizedBox(height: 8),
        if (innings.isEmpty)
          const Text('—', style: TextStyle(color: SGColors.textMuted, fontSize: 20, fontWeight: FontWeight.w700))
        else
          ...innings.asMap().entries.map((e) {
            final i = e.value;
            final isLatest = e.key == innings.length - 1;
            return Text(
              '${i.scoreString} ${i.oversString}${i.declared ? ' d' : ''}',
              textAlign: align,
              style: TextStyle(
                color:      isLatest ? SGColors.textPrimary : SGColors.textSecondary,
                fontSize:   isLatest ? 22 : 15,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            );
          }),
      ],
    );
  }

  Widget _logo() {
    if (team.imageUrl.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: team.imageUrl,
          width: 32, height: 32,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => _placeholder(),
        ),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() => Container(
    width: 32, height: 32,
    decoration: BoxDecoration(
      color:  SGColors.textMuted.withValues(alpha: 0.2),
      shape:  BoxShape.circle,
    ),
    alignment: Alignment.center,
    child: Text(
      team.short.isNotEmpty ? team.short.substring(0, 2) : '??',
      style: const TextStyle(color: SGColors.textMuted, fontSize: 10, fontWeight: FontWeight.w700),
    ),
  );
}
