import 'package:flutter_test/flutter_test.dart';
import 'package:sportgod/models/cricket_models.dart';
import 'package:sportgod/screens/fantasy/team_builder_screen.dart';

void main() {
  group('FantasyPoints.calcBatting', () {
    test('basic run scoring', () {
      final b = BattingRow.fromJson({
        'runs': 30, 'balls': 20, 'fours': 3, 'sixes': 1,
        'strike_rate': 150.0, 'how_out': 'caught',
      });
      // 30 runs + 3 fours bonus + 1 six * 2 bonus = 30 + 3 + 2 = 35
      expect(FantasyPoints.calcBatting(b), 35.0);
    });

    test('half century bonus', () {
      final b = BattingRow.fromJson({
        'runs': 55, 'balls': 40, 'fours': 5, 'sixes': 2,
        'strike_rate': 137.5, 'how_out': 'caught',
      });
      // 55 + 5 + 4 + 8 (half century) = 72
      expect(FantasyPoints.calcBatting(b), 72.0);
    });

    test('century bonus', () {
      final b = BattingRow.fromJson({
        'runs': 100, 'balls': 60, 'fours': 10, 'sixes': 4,
        'strike_rate': 166.67, 'how_out': 'not out',
      });
      // 100 + 10 + 8 + 16 (century) + 4 (SR > 150) = 138
      expect(FantasyPoints.calcBatting(b), 138.0);
    });

    test('duck penalty', () {
      final b = BattingRow.fromJson({
        'runs': 0, 'balls': 3, 'fours': 0, 'sixes': 0,
        'strike_rate': 0.0, 'how_out': 'bowled',
      });
      // 0 + (-2 duck) = -2
      expect(FantasyPoints.calcBatting(b), -2.0);
    });

    test('no duck penalty if not out', () {
      final b = BattingRow.fromJson({
        'runs': 0, 'balls': 2, 'fours': 0, 'sixes': 0,
        'strike_rate': 0.0, 'how_out': 'not out',
      });
      expect(FantasyPoints.calcBatting(b), 0.0);
    });

    test('strike rate bonus > 150 in T20', () {
      final b = BattingRow.fromJson({
        'runs': 20, 'balls': 12, 'fours': 2, 'sixes': 1,
        'strike_rate': 166.67, 'how_out': 'caught',
      });
      // 20 + 2 + 2 + 4 (SR bonus) = 28
      expect(FantasyPoints.calcBatting(b, matchType: 'T20'), 28.0);
    });

    test('no SR bonus/penalty in Test', () {
      final b = BattingRow.fromJson({
        'runs': 5, 'balls': 30, 'fours': 1, 'sixes': 0,
        'strike_rate': 16.67, 'how_out': 'caught',
      });
      // 5 + 1 = 6 (no SR penalty for Test)
      expect(FantasyPoints.calcBatting(b, matchType: 'Test'), 6.0);
    });
  });

  group('FantasyPoints.calcBowling', () {
    test('basic wickets', () {
      final b = BowlingRow.fromJson({
        'overs': 4.0, 'maidens': 0, 'runs': 30, 'wickets': 2,
        'economy': 7.5,
      });
      // 2 * 25 = 50
      expect(FantasyPoints.calcBowling(b), 50.0);
    });

    test('three wicket bonus', () {
      final b = BowlingRow.fromJson({
        'overs': 4.0, 'maidens': 1, 'runs': 24, 'wickets': 3,
        'economy': 6.0,
      });
      // 3*25 + 1*8 + 4 (3-wkt bonus) = 75 + 8 + 4 = 87
      expect(FantasyPoints.calcBowling(b), 87.0);
    });

    test('five wicket bonus', () {
      final b = BowlingRow.fromJson({
        'overs': 4.0, 'maidens': 1, 'runs': 16, 'wickets': 5,
        'economy': 4.0,
      });
      // 5*25 + 1*8 + 16 (5-wkt) + 6 (econ < 5) = 125 + 8 + 16 + 6 = 155
      expect(FantasyPoints.calcBowling(b), 155.0);
    });

    test('economy penalty > 12', () {
      final b = BowlingRow.fromJson({
        'overs': 3.0, 'maidens': 0, 'runs': 42, 'wickets': 0,
        'economy': 14.0,
      });
      // 0 + (-4 economy) = -4
      expect(FantasyPoints.calcBowling(b), -4.0);
    });

    test('no economy bonus/penalty under 2 overs', () {
      final b = BowlingRow.fromJson({
        'overs': 1.0, 'maidens': 0, 'runs': 20, 'wickets': 0,
        'economy': 20.0,
      });
      expect(FantasyPoints.calcBowling(b), 0.0);
    });
  });

  group('FantasyPoints.calcTotal', () {
    test('captain multiplier', () {
      final sc = Scorecard.fromJson({
        'match_id': '1',
        'batting': [
          {'player_id': 'p1', 'runs': 50, 'balls': 30, 'fours': 5, 'sixes': 2, 'strike_rate': 166.67, 'how_out': 'caught'},
        ],
        'bowling': [],
        'runs': [],
      });
      final normal = FantasyPoints.calcTotal(playerId: 'p1', scorecard: sc, matchType: 'T20');
      final captain = FantasyPoints.calcTotal(playerId: 'p1', scorecard: sc, matchType: 'T20', isCaptain: true);
      expect(captain, normal * 2.0);
    });

    test('vice captain multiplier', () {
      final sc = Scorecard.fromJson({
        'match_id': '1',
        'batting': [
          {'player_id': 'p1', 'runs': 30, 'balls': 20, 'fours': 3, 'sixes': 1, 'strike_rate': 150.0, 'how_out': 'caught'},
        ],
        'bowling': [],
        'runs': [],
      });
      final normal = FantasyPoints.calcTotal(playerId: 'p1', scorecard: sc, matchType: 'T20');
      final vc = FantasyPoints.calcTotal(playerId: 'p1', scorecard: sc, matchType: 'T20', isViceCaptain: true);
      expect(vc, normal * 1.5);
    });
  });
}
