import 'package:flutter/material.dart';
import '../models/cricket_models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class HeadToHeadWidget extends StatefulWidget {
  final CricketMatch match;
  const HeadToHeadWidget({super.key, required this.match});

  @override
  State<HeadToHeadWidget> createState() => _HeadToHeadWidgetState();
}

class _HeadToHeadWidgetState extends State<HeadToHeadWidget> {
  final _api = ApiService();
  late final Future<Map<String, dynamic>?> _h2hFuture;

  @override
  void initState() {
    super.initState();
    _h2hFuture = _api.getHeadToHead(widget.match.id);
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _h2hFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
        }
        final data = snapshot.data;
        if (data == null) return const SizedBox.shrink();

        final homeWins    = (data['home_wins']      ?? 0) as int;
        final awayWins    = (data['away_wins']       ?? 0) as int;
        final totalMatches = (data['total_matches']  ?? 0) as int;
        final homeAvg     = (data['home_avg_score']  ?? 0) as int;
        final awayAvg     = (data['away_avg_score']  ?? 0) as int;

        if (totalMatches == 0) return const SizedBox.shrink();

        final homeWinPct = (homeWins / totalMatches * 100).round();
        final awayWinPct = (awayWins / totalMatches * 100).round();

        return SGCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.compare_arrows_rounded, color: SGColors.textSecondary, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Head to Head  ($totalMatches matches)',
                    style: const TextStyle(
                      color: SGColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Team name headers
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(widget.match.teamHome.short, style: const TextStyle(
                    color: SGColors.boundary, fontSize: 13, fontWeight: FontWeight.w700,
                  )),
                  Text(widget.match.teamAway.short, style: const TextStyle(
                    color: SGColors.wicket, fontSize: 13, fontWeight: FontWeight.w700,
                  )),
                ],
              ),
              const SizedBox(height: 12),

              _ComparisonBar(label: 'Wins',      homeValue: homeWins,    awayValue: awayWins),
              const SizedBox(height: 10),
              _ComparisonBar(label: 'Win %',     homeValue: homeWinPct,  awayValue: awayWinPct, suffix: '%'),
              const SizedBox(height: 10),
              _ComparisonBar(label: 'Avg Score', homeValue: homeAvg,     awayValue: awayAvg),
            ],
          ),
        );
      },
    );
  }
}

class _ComparisonBar extends StatelessWidget {
  final String label;
  final int    homeValue;
  final int    awayValue;
  final String suffix;

  const _ComparisonBar({
    required this.label,
    required this.homeValue,
    required this.awayValue,
    this.suffix = '',
  });

  @override
  Widget build(BuildContext context) {
    final total = homeValue + awayValue;
    // Avoid division by zero — split evenly when both are 0
    final homeFlex = total > 0 ? homeValue : 1;
    final awayFlex = total > 0 ? awayValue : 1;

    return Column(
      children: [
        Row(
          children: [
            SizedBox(
              width: 40,
              child: Text(
                '$homeValue$suffix',
                style: const TextStyle(color: SGColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  Text(label, style: const TextStyle(
                    color: SGColors.textMuted, fontSize: 10, fontWeight: FontWeight.w600,
                  )),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Row(
                      children: [
                        Flexible(
                          flex: homeFlex,
                          child: Container(height: 6, color: SGColors.boundary),
                        ),
                        const SizedBox(width: 2),
                        Flexible(
                          flex: awayFlex,
                          child: Container(height: 6, color: SGColors.wicket),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 40,
              child: Text(
                '$awayValue$suffix',
                textAlign: TextAlign.right,
                style: const TextStyle(color: SGColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
