import 'package:flutter_test/flutter_test.dart';
import 'package:sportgod/models/contest_models.dart';

void main() {
  group('Contest', () {
    test('fromJson parses snake_case fields', () {
      final c = Contest.fromJson({
        'id': 'c1',
        'contest_code': 'ABCD',
        'match_id': 'm1',
        'contest_type': 'private',
        'title': 'My Contest',
        'entry_fee': 50,
        'max_players': 100,
        'player_count': 30,
        'prize_pool': 5000,
        'status': 'open',
        'invite_code': 'XYZ',
        'joined': true,
        'spots_left': 70,
        'fill_pct': 30,
      });
      expect(c.id, 'c1');
      expect(c.contestCode, 'ABCD');
      expect(c.isPublic, false);
      expect(c.isFull, false);
      expect(c.joined, true);
      expect(c.spotsLeft, 70);
    });

    test('fromJson parses camelCase fields', () {
      final c = Contest.fromJson({
        'id': 'c2',
        'contestCode': 'EFGH',
        'matchId': 'm2',
        'contestType': 'public',
        'entryFee': 0,
        'maxPlayers': 50,
        'playerCount': 50,
        'spotsLeft': 0,
      });
      expect(c.isPublic, true);
      expect(c.isFull, true);
    });

    test('handles empty json', () {
      final c = Contest.fromJson({});
      expect(c.id, '');
      expect(c.status, 'open');
      expect(c.entryFee, 0);
    });
  });

  group('PrizeBreakdown', () {
    test('fromJson parses correctly', () {
      final p = PrizeBreakdown.fromJson({'rank': 1, 'pct': 50});
      expect(p.rank, 1);
      expect(p.pct, 50);
    });
  });

  group('PartnerData', () {
    test('fromJson parses correctly', () {
      final p = PartnerData.fromJson({
        'id': 'p1',
        'ref_code': 'REF123',
        'status': 'active',
        'total_referrals': 60,
        'active_referrals': 45,
        'total_earned': 1500.5,
        'pending_payout': 200.0,
      });
      expect(p.id, 'p1');
      expect(p.refCode, 'REF123');
      expect(p.isActive, true);
      expect(p.isPending, false);
      expect(p.totalReferrals, 60);
      expect(p.totalEarned, 1500.5);
    });
  });

  group('Earning', () {
    test('fromJson parses correctly', () {
      final e = Earning.fromJson({
        'id': 'e1',
        'amount': 100.5,
        'source': 'contest',
        'description': 'Contest earnings',
        'created_at': '2026-05-19T10:00:00Z',
      });
      expect(e.id, 'e1');
      expect(e.amount, 100.5);
      expect(e.source, 'contest');
    });
  });
}
