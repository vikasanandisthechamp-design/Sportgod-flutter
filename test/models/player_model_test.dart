import 'package:flutter_test/flutter_test.dart';
import 'package:sportgod/models/player_model.dart';

void main() {
  group('Player', () {
    test('fromJson parses correctly', () {
      final p = Player.fromJson({
        'id': '42',
        'name': 'MS Dhoni',
        'team_id': '1',
        'team_name': 'Chennai Super Kings',
        'team_short': 'CSK',
        'role': 'WK',
        'country': 'India',
        'image_url': 'https://example.com/dhoni.png',
        'batting_avg': 38.1,
        'bowling_avg': 0.0,
        'strike_rate': 135.2,
        'economy': 0.0,
        'matches': 234,
        'runs': 5082,
        'wickets': 0,
        'catches': 120,
        'fantasy_cost': 10.5,
      });
      expect(p.name, 'MS Dhoni');
      expect(p.roleLabel, 'Wicket-Keeper');
      expect(p.matches, 234);
      expect(p.fantasyCost, 10.5);
    });

    test('roleLabel returns human-readable values', () {
      expect(Player.fromJson({'role': 'BAT'}).roleLabel, 'Batter');
      expect(Player.fromJson({'role': 'BWL'}).roleLabel, 'Bowler');
      expect(Player.fromJson({'role': 'AR'}).roleLabel, 'All-Rounder');
      expect(Player.fromJson({'role': 'WK'}).roleLabel, 'Wicket-Keeper');
      expect(Player.fromJson({'role': 'OTHER'}).roleLabel, 'OTHER');
    });

    test('handles missing fields', () {
      final p = Player.fromJson({});
      expect(p.id, '');
      expect(p.name, '');
      expect(p.battingAvg, 0.0);
      expect(p.matches, 0);
    });
  });

  group('RecentForm', () {
    test('fromJson parses correctly', () {
      final f = RecentForm.fromJson({
        'match_id': 'm1',
        'opponent': 'MI',
        'runs': 75,
        'wickets': 0,
        'balls': 48,
        'strike_rate': 156.25,
        'date': '2026-05-15',
      });
      expect(f.opponent, 'MI');
      expect(f.runs, 75);
      expect(f.strikeRate, 156.25);
    });
  });
}
