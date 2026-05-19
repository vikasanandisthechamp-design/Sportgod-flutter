/// Player profile model for the /api/v1/players/:id endpoint.
class Player {
  final String id;
  final String name;
  final String teamId;
  final String teamName;
  final String teamShort;
  final String role;       // BAT | BWL | AR | WK
  final String country;
  final String imageUrl;
  final double battingAvg;
  final double bowlingAvg;
  final double strikeRate;
  final double economy;
  final int    matches;
  final int    runs;
  final int    wickets;
  final int    catches;
  final double fantasyCost;

  const Player({
    required this.id,
    required this.name,
    required this.teamId,
    required this.teamName,
    required this.teamShort,
    required this.role,
    required this.country,
    required this.imageUrl,
    required this.battingAvg,
    required this.bowlingAvg,
    required this.strikeRate,
    required this.economy,
    required this.matches,
    required this.runs,
    required this.wickets,
    required this.catches,
    required this.fantasyCost,
  });

  factory Player.fromJson(Map<String, dynamic> j) => Player(
    id:         (j['id'] ?? '').toString(),
    name:       j['name']       ?? '',
    teamId:     (j['team_id']   ?? '').toString(),
    teamName:   j['team_name']  ?? '',
    teamShort:  j['team_short'] ?? '',
    role:       j['role']       ?? 'BAT',
    country:    j['country']    ?? '',
    imageUrl:   j['image_url']  ?? '',
    battingAvg: (j['batting_avg']  ?? 0).toDouble(),
    bowlingAvg: (j['bowling_avg']  ?? 0).toDouble(),
    strikeRate: (j['strike_rate']  ?? 0).toDouble(),
    economy:    (j['economy']      ?? 0).toDouble(),
    matches:    (j['matches']      ?? 0) as int,
    runs:       (j['runs']         ?? 0) as int,
    wickets:    (j['wickets']      ?? 0) as int,
    catches:    (j['catches']      ?? 0) as int,
    fantasyCost:(j['fantasy_cost'] ?? 0).toDouble(),
  );

  /// Human-readable role label.
  String get roleLabel => switch (role) {
    'BAT' => 'Batter',
    'BWL' => 'Bowler',
    'AR'  => 'All-Rounder',
    'WK'  => 'Wicket-Keeper',
    _     => role,
  };
}

/// A single recent-form entry (last 5 matches).
class RecentForm {
  final String matchId;
  final String opponent;
  final int    runs;
  final int    wickets;
  final int    balls;
  final double strikeRate;
  final String date;

  const RecentForm({
    required this.matchId,
    required this.opponent,
    required this.runs,
    required this.wickets,
    required this.balls,
    required this.strikeRate,
    required this.date,
  });

  factory RecentForm.fromJson(Map<String, dynamic> j) => RecentForm(
    matchId:    (j['match_id'] ?? '').toString(),
    opponent:   j['opponent']  ?? '',
    runs:       (j['runs']     ?? 0) as int,
    wickets:    (j['wickets']  ?? 0) as int,
    balls:      (j['balls']    ?? 0) as int,
    strikeRate: (j['strike_rate'] ?? 0).toDouble(),
    date:       j['date']      ?? '',
  );
}
