import 'package:flutter_test/flutter_test.dart';
import 'package:sportgod/models/cricket_models.dart';

void main() {
  group('Team', () {
    test('fromJson parses correctly', () {
      final t = Team.fromJson({
        'id': '1',
        'name': 'Chennai Super Kings',
        'short': 'CSK',
        'image_url': 'https://example.com/csk.png',
        'country': 'India',
      });
      expect(t.id, '1');
      expect(t.name, 'Chennai Super Kings');
      expect(t.short, 'CSK');
      expect(t.imageUrl, 'https://example.com/csk.png');
      expect(t.country, 'India');
    });

    test('fromJson handles missing fields', () {
      final t = Team.fromJson({});
      expect(t.id, '');
      expect(t.name, '');
      expect(t.short, '');
    });
  });

  group('InningsRun', () {
    test('fromJson parses correctly', () {
      final r = InningsRun.fromJson({
        'team_id': 42,
        'inning': 2,
        'score': 187,
        'wickets': 4,
        'overs': '18.3',
        'declared': false,
      });
      expect(r.teamId, '42');
      expect(r.inning, 2);
      expect(r.score, 187);
      expect(r.wickets, 4);
      expect(r.overs, '18.3');
      expect(r.scoreString, '187/4');
      expect(r.oversString, '(18.3 ov)');
    });
  });

  group('CricketMatch', () {
    test('fromJson parses full match', () {
      final m = CricketMatch.fromJson({
        'id': 123,
        'note': 'CSK won by 5 wickets',
        'status': 'Live',
        'match_type': 'T20',
        'team_home': {'id': '1', 'name': 'CSK', 'short': 'CSK', 'image_url': '', 'country': 'India'},
        'team_away': {'id': '2', 'name': 'MI', 'short': 'MI', 'image_url': '', 'country': 'India'},
        'runs': [
          {'team_id': '1', 'inning': 1, 'score': 180, 'wickets': 6, 'overs': '20', 'declared': false},
        ],
        'venue': {'name': 'Wankhede', 'city': 'Mumbai'},
        'date': '2026-05-19',
      });
      expect(m.id, '123');
      expect(m.isLive, true);
      expect(m.isUpcoming, false);
      expect(m.hasStarted, true);
      expect(m.teamHome.short, 'CSK');
      expect(m.runs.length, 1);
      expect(m.venue, 'Wankhede, Mumbai');
    });

    test('status helpers', () {
      expect(CricketMatch.fromJson({'status': 'NS'}).isUpcoming, true);
      expect(CricketMatch.fromJson({'status': 'Finished'}).isFinished, true);
      expect(CricketMatch.fromJson({'status': 'Complete'}).isFinished, true);
      expect(CricketMatch.fromJson({'status': 'Inning Break'}).hasStarted, true);
    });

    test('runsFor filters by team', () {
      final m = CricketMatch.fromJson({
        'team_home': {'id': '1'},
        'team_away': {'id': '2'},
        'runs': [
          {'team_id': '1', 'inning': 1, 'score': 150, 'wickets': 8, 'overs': '20'},
          {'team_id': '2', 'inning': 1, 'score': 120, 'wickets': 10, 'overs': '18.4'},
        ],
      });
      expect(m.runsFor('1').length, 1);
      expect(m.runsFor('1').first.score, 150);
      expect(m.runsFor('2').first.score, 120);
    });
  });

  group('BattingRow', () {
    test('fromJson parses correctly', () {
      final b = BattingRow.fromJson({
        'player_id': 'p1',
        'player_name': 'Virat Kohli',
        'team_id': '1',
        'inning': 'S1',
        'runs': 82,
        'balls': 53,
        'fours': 8,
        'sixes': 3,
        'strike_rate': 154.7,
        'how_out': 'caught',
      });
      expect(b.playerName, 'Virat Kohli');
      expect(b.runs, 82);
      expect(b.isNotOut, false);
    });

    test('isNotOut', () {
      final b = BattingRow.fromJson({'how_out': 'not out'});
      expect(b.isNotOut, true);
    });
  });

  group('BowlingRow', () {
    test('fromJson parses correctly', () {
      final b = BowlingRow.fromJson({
        'player_id': 'p2',
        'player_name': 'Bumrah',
        'team_id': '2',
        'inning': 'S1',
        'overs': 4.0,
        'maidens': 1,
        'runs': 24,
        'wickets': 3,
        'economy': 6.0,
      });
      expect(b.playerName, 'Bumrah');
      expect(b.wickets, 3);
      expect(b.economy, 6.0);
    });
  });

  group('BallEvent', () {
    test('badgeLabel returns correct values', () {
      expect(BallEvent.fromJson({'is_wicket': true}).badgeLabel, 'W');
      expect(BallEvent.fromJson({'is_six': true}).badgeLabel, '6');
      expect(BallEvent.fromJson({'is_four': true}).badgeLabel, '4');
      expect(BallEvent.fromJson({'is_wide': true}).badgeLabel, 'WD');
      expect(BallEvent.fromJson({'is_noball': true}).badgeLabel, 'NB');
      expect(BallEvent.fromJson({'runs': 2}).badgeLabel, '2');
    });
  });

  group('Prediction', () {
    test('fromJson parses correctly', () {
      final p = Prediction.fromJson({
        'win_probability': {'team_home': 65, 'team_away': 35},
        'momentum': 'home',
        'momentum_reason': 'Strong batting',
        'key_insight': 'Key insight text',
        'prediction_summary': 'Summary',
        'risk_factors': ['factor 1', 'factor 2'],
        'confidence': 8,
      });
      expect(p.homeProb, 65);
      expect(p.awayProb, 35);
      expect(p.momentum, 'home');
      expect(p.confidence, 8);
      expect(p.riskFactors.length, 2);
      expect(p.hasError, false);
    });

    test('empty() has error flag', () {
      final p = Prediction.empty();
      expect(p.hasError, true);
      expect(p.homeProb, 50);
      expect(p.awayProb, 50);
    });
  });

  group('Scorecard', () {
    test('fromJson parses correctly', () {
      final s = Scorecard.fromJson({
        'match_id': '123',
        'batting': [
          {'player_id': 'p1', 'player_name': 'A', 'runs': 50, 'balls': 30},
        ],
        'bowling': [
          {'player_id': 'p2', 'player_name': 'B', 'overs': 4.0, 'wickets': 2, 'runs': 28},
        ],
        'runs': [
          {'team_id': '1', 'inning': 1, 'score': 180, 'wickets': 6, 'overs': '20'},
        ],
      });
      expect(s.matchId, '123');
      expect(s.batting.length, 1);
      expect(s.bowling.length, 1);
      expect(s.runs.length, 1);
    });
  });
}
