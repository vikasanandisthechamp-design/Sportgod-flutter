import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/cricket_models.dart';
import '../theme/app_theme.dart';

/// A worm chart showing cumulative run progression over overs for both teams.
///
/// Uses the [Scorecard.runs] list to derive per-innings data.  When detailed
/// over-by-over data isn't available it falls back to a simple 2-point line
/// from (0, 0) to (overs, score) for each innings.
class WormChartWidget extends StatelessWidget {
  final Scorecard    scorecard;
  final CricketMatch match;

  const WormChartWidget({
    super.key,
    required this.scorecard,
    required this.match,
  });

  // ── Colours ────────────────────────────────────────────────────────────
  static const _homeColor = Color(0xFF3B82F6); // blue
  static const _awayColor = Color(0xFFEF4444); // red

  // ── Data helpers ───────────────────────────────────────────────────────

  /// Build spots for a team's innings.
  ///
  /// Each [InningsRun] has a total score and an overs string (e.g. "14.3").
  /// If only one innings entry exists we draw a straight line from the origin;
  /// if multiple innings exist (test matches) we accumulate them.
  List<FlSpot> _buildSpots(List<InningsRun> innings) {
    if (innings.isEmpty) return [];

    final spots = <FlSpot>[const FlSpot(0, 0)];

    // Sort by inning number so we accumulate in order.
    final sorted = List<InningsRun>.from(innings)
      ..sort((a, b) => a.inning.compareTo(b.inning));

    double cumulativeOvers = 0;
    double cumulativeRuns  = 0;

    for (final inn in sorted) {
      final overs = double.tryParse(inn.overs) ?? 0;
      cumulativeOvers += overs;
      cumulativeRuns  += inn.score;
      spots.add(FlSpot(cumulativeOvers, cumulativeRuns));
    }

    return spots;
  }

  double _maxX(List<FlSpot> homeSpots, List<FlSpot> awaySpots) {
    double mx = 1;
    for (final s in homeSpots) {
      if (s.x > mx) mx = s.x;
    }
    for (final s in awaySpots) {
      if (s.x > mx) mx = s.x;
    }
    return mx;
  }

  double _maxY(List<FlSpot> homeSpots, List<FlSpot> awaySpots) {
    double my = 1;
    for (final s in homeSpots) {
      if (s.y > my) my = s.y;
    }
    for (final s in awaySpots) {
      if (s.y > my) my = s.y;
    }
    return my;
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Derive innings data — prefer scorecard.runs, fall back to match.runs.
    final runsSource = scorecard.runs.isNotEmpty ? scorecard.runs : match.runs;

    final homeTeamId = match.teamHome.id;
    final awayTeamId = match.teamAway.id;

    // Partition by team — use the same fuzzy-matching logic as CricketMatch.
    List<InningsRun> homeInnings;
    List<InningsRun> awayInnings;

    if (scorecard.runs.isNotEmpty) {
      homeInnings = runsSource.where((r) => r.teamId == homeTeamId).toList();
      awayInnings = runsSource.where((r) => r.teamId == awayTeamId).toList();
      // Fuzzy fallback: assign by inning parity if exact match fails.
      if (homeInnings.isEmpty && awayInnings.isEmpty) {
        homeInnings = runsSource.where((r) => r.inning % 2 == 1).toList();
        awayInnings = runsSource.where((r) => r.inning % 2 == 0).toList();
      }
    } else {
      homeInnings = match.homeRuns;
      awayInnings = match.awayRuns;
    }

    final homeSpots = _buildSpots(homeInnings);
    final awaySpots = _buildSpots(awayInnings);

    // Nothing to render.
    if (homeSpots.isEmpty && awaySpots.isEmpty) {
      return const SizedBox.shrink();
    }

    final maxX = _maxX(homeSpots, awaySpots);
    final maxY = _maxY(homeSpots, awaySpots);

    // Round Y max up to the nearest 25 for nicer grid lines.
    final yMax = ((maxY / 25).ceil() * 25).toDouble().clamp(25, double.infinity);

    return SGCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Title row ──────────────────────────────────────────
          Row(
            children: [
              const Icon(Icons.show_chart_rounded,
                  color: SGColors.textSecondary, size: 18),
              const SizedBox(width: 8),
              const Text(
                'Run Rate',
                style: TextStyle(
                  color: SGColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              // Legend
              _LegendDot(color: _homeColor, label: match.teamHome.short),
              const SizedBox(width: 12),
              _LegendDot(color: _awayColor, label: match.teamAway.short),
            ],
          ),
          const SizedBox(height: 20),

          // ── Chart ──────────────────────────────────────────────
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: maxX,
                minY: 0,
                maxY: yMax,
                clipData: const FlClipData.all(),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  drawHorizontalLine: true,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: Colors.white.withValues(alpha: 0.06),
                    strokeWidth: 1,
                  ),
                  getDrawingVerticalLine: (_) => FlLine(
                    color: Colors.white.withValues(alpha: 0.06),
                    strokeWidth: 1,
                  ),
                  horizontalInterval: yMax > 100 ? 50 : 25,
                  verticalInterval: (maxX / 4).ceilToDouble().clamp(1, double.infinity),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: (maxX / 4).ceilToDouble().clamp(1, double.infinity),
                      getTitlesWidget: (value, _) {
                        if (value == 0) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            '${value.toInt()}',
                            style: const TextStyle(
                              color: SGColors.textMuted,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      },
                    ),
                    axisNameWidget: const Text(
                      'Overs',
                      style: TextStyle(
                        color: SGColors.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    axisNameSize: 18,
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      interval: yMax > 100 ? 50 : 25,
                      getTitlesWidget: (value, _) {
                        if (value == 0) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Text(
                            '${value.toInt()}',
                            style: const TextStyle(
                              color: SGColors.textMuted,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) =>
                        SGColors.card.withValues(alpha: 0.95),
                    tooltipBorderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                    tooltipRoundedRadius: 8,
                    tooltipPadding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final isHome = spot.barIndex == 0;
                        final teamName = isHome
                            ? match.teamHome.short
                            : match.teamAway.short;
                        final color = isHome ? _homeColor : _awayColor;
                        return LineTooltipItem(
                          '$teamName: ${spot.y.toInt()}',
                          TextStyle(
                            color: color,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
                lineBarsData: [
                  if (homeSpots.isNotEmpty) _buildLine(homeSpots, _homeColor),
                  if (awaySpots.isNotEmpty) _buildLine(awaySpots, _awayColor),
                ],
              ),
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
            ),
          ),
        ],
      ),
    );
  }

  LineChartBarData _buildLine(List<FlSpot> spots, Color color) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.25,
      preventCurveOverShooting: true,
      color: color,
      barWidth: 2.5,
      isStrokeCapRound: true,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, bar, index) {
          // Only show a dot for the last point (current score).
          if (index == spots.length - 1) {
            return FlDotCirclePainter(
              radius: 4,
              color: color,
              strokeWidth: 2,
              strokeColor: SGColors.card,
            );
          }
          return FlDotCirclePainter(radius: 0, color: Colors.transparent);
        },
      ),
      belowBarData: BarAreaData(
        show: true,
        color: color.withValues(alpha: 0.08),
      ),
    );
  }
}

// ── Legend dot ────────────────────────────────────────────────────────────

class _LegendDot extends StatelessWidget {
  final Color  color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
