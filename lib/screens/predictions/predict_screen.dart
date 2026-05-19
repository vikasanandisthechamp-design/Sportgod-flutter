import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/env_config.dart';
import '../../providers/coins_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shimmer_loading.dart';

class PredictScreen extends StatefulWidget {
  final String matchId;
  const PredictScreen({super.key, required this.matchId});

  @override
  State<PredictScreen> createState() => _PredictScreenState();
}

class _PredictScreenState extends State<PredictScreen> {
  List<Map<String, dynamic>> _questions = [];
  final Map<String, _Selection> _selections = {};
  bool _loading = true;
  bool _submitting = false;
  String? _error;
  int _betAmount = 25;

  static const _betOptions = [10, 25, 50, 100];

  final _sb = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      // ── 1. Load questions from Supabase directly ──────────────────
      final qRes = await _sb
          .from('prediction_questions')
          .select('*')
          .eq('match_id', widget.matchId)
          .order('created_at', ascending: true);

      List<Map<String, dynamic>> questions =
          (qRes as List).cast<Map<String, dynamic>>();

      // ── 2. If no questions yet, trigger auto-generation via web API ─
      if (questions.isEmpty) {
        questions = await _autoGenerate();
      }

      // ── 3. Decorate with user's existing bets ─────────────────────
      if (questions.isNotEmpty) {
        final userId = _sb.auth.currentUser?.id;
        if (userId != null) {
          final qIds = questions.map((q) => q['id']).toList();
          final bets = await _sb
              .from('user_predictions')
              .select('question_id, predicted_value, coins_wagered, status, context')
              .eq('user_id', userId)
              .inFilter('question_id', qIds);

          final betMap = <String, Map<String, dynamic>>{};
          for (final b in (bets as List).cast<Map<String, dynamic>>()) {
            betMap[b['question_id'] as String] = b;
          }

          questions = questions.map((q) {
            final bet = betMap[q['id'] as String];
            if (bet != null) {
              final ctx = bet['context'] is Map
                  ? bet['context'] as Map<String, dynamic>
                  : <String, dynamic>{};
              return {
                ...q,
                'user_bet': {
                  'option_id':    bet['predicted_value'],
                  'option_label': ctx['option_label'] ?? bet['predicted_value'],
                  'coins':        bet['coins_wagered'],
                  'status':       bet['status'] == 'correct'
                                    ? 'won'
                                    : bet['status'] == 'incorrect'
                                    ? 'lost'
                                    : 'pending',
                },
              };
            }
            return q;
          }).toList();
        }
      }

      if (mounted) {
        setState(() {
          _questions = questions;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = 'Failed to load predictions'; _loading = false; });
    }
  }

  /// Call the Next.js API to auto-generate standard questions for this match.
  Future<List<Map<String, dynamic>>> _autoGenerate() async {
    try {
      final token = _sb.auth.currentSession?.accessToken;
      final res = await http.get(
        Uri.parse('${Env.webBaseUrl}/api/v2/predictions/${widget.matchId}'),
        headers: {if (token != null) 'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = json.decode(res.body) as Map<String, dynamic>;
        final list = (data['questions'] ?? []) as List;
        return list.cast<Map<String, dynamic>>();
      }
    } catch (_) {}
    return [];
  }

  int get _totalCost => _selections.length * _betAmount;

  Future<void> _submit() async {
    if (_selections.isEmpty) return;

    final balance = context.read<CoinsProvider>().balance;
    if (_totalCost > balance) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Not enough coins. Need $_totalCost, have $balance.'),
        backgroundColor: Colors.redAccent,
      ));
      return;
    }

    setState(() => _submitting = true);
    final token = _sb.auth.currentSession?.accessToken;
    if (token == null) { setState(() => _submitting = false); return; }

    int submitted = 0, failed = 0;
    for (final entry in _selections.entries) {
      final sel = entry.value;
      try {
        // Submit via Next.js web API — handles atomic coin deduction
        final res = await http.post(
          Uri.parse('${Env.webBaseUrl}/api/v2/predictions/submit'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: json.encode({
            'question_id':     entry.key,
            'selected_option': sel.optionId,
            'selected_label':  sel.optionLabel,
            'coins_wagered':   sel.coins,
          }),
        ).timeout(const Duration(seconds: 12));
        if (res.statusCode == 200 || res.statusCode == 201) {
          submitted++;
        } else {
          failed++;
        }
      } catch (_) {
        failed++;
      }
    }

    if (mounted) {
      context.read<CoinsProvider>().sync(token);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          failed == 0
            ? '✅ $submitted pick(s) locked in!'
            : '$submitted submitted, $failed failed.',
        ),
        backgroundColor: failed == 0 ? const Color(0xFF00E5A8) : Colors.orange,
      ));
      setState(() { _submitting = false; _selections.clear(); });
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final coins = context.watch<CoinsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Predictions'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(child: Row(children: [
              const Icon(Icons.stars_rounded, size: 18, color: Color(0xFFFFD700)),
              const SizedBox(width: 4),
              Text('${coins.balance}', style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFFFFD700),
              )),
            ])),
          ),
        ],
      ),
      body: _loading
          ? const ShimmerList(itemCount: 4)
          : _error != null
              ? _ErrorState(error: _error!, onRetry: _load)
              : _questions.isEmpty
                  ? _EmptyState(onRetry: _load)
                  : Column(children: [
                      // Disclaimer
                      _Disclaimer(),
                      // Bet amount selector
                      _BetSelector(
                        options: _betOptions,
                        selected: _betAmount,
                        onChanged: (v) => setState(() => _betAmount = v),
                      ),
                      // Question list
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _questions.length,
                            itemBuilder: (_, i) => _QuestionCard(
                              question: _questions[i],
                              selection: _selections[_questions[i]['id']?.toString() ?? ''],
                              betAmount: _betAmount,
                              onSelect: (qId, sel) => setState(() {
                                if (sel == null) {
                                  _selections.remove(qId);
                                } else {
                                  _selections[qId] = sel;
                                }
                              }),
                            ),
                          ),
                        ),
                      ),
                      // Submit bar
                      if (_selections.isNotEmpty)
                        SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: SizedBox(
                              width: double.infinity, height: 50,
                              child: ElevatedButton(
                                onPressed: _submitting ? null : _submit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF00E5A8),
                                  foregroundColor: const Color(0xFF0F0F11),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                child: _submitting
                                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                                    : Text(
                                        'Lock ${_selections.length} Pick(s) · $_totalCost coins',
                                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                                      ),
                              ),
                            ),
                          ),
                        ),
                    ]),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _Disclaimer extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: const Color(0xFF6366F1).withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.2)),
    ),
    child: Row(children: [
      const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF6366F1)),
      const SizedBox(width: 8),
      Expanded(child: Text(
        'Points-only game. No real money involved.',
        style: TextStyle(fontSize: 11, color: const Color(0xFF6366F1).withValues(alpha: 0.9)),
      )),
    ]),
  );
}

class _BetSelector extends StatelessWidget {
  final List<int> options;
  final int selected;
  final ValueChanged<int> onChanged;
  const _BetSelector({required this.options, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
    child: Row(children: [
      const Text('COINS PER PICK:', style: TextStyle(
        fontSize: 10, fontWeight: FontWeight.w800,
        color: SGColors.textMuted, letterSpacing: 1.0,
      )),
      const SizedBox(width: 10),
      ...options.map((amt) {
        final active = amt == selected;
        return Padding(
          padding: const EdgeInsets.only(right: 6),
          child: GestureDetector(
            onTap: () => onChanged(amt),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: active ? const Color(0xFF00E5A8).withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: active ? const Color(0xFF00E5A8).withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.08),
                ),
              ),
              child: Text('$amt', style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700,
                color: active ? const Color(0xFF00E5A8) : SGColors.textSecondary,
              )),
            ),
          ),
        );
      }),
    ]),
  );
}

class _QuestionCard extends StatelessWidget {
  final Map<String, dynamic> question;
  final _Selection? selection;
  final int betAmount;
  final void Function(String qId, _Selection? sel) onSelect;
  const _QuestionCard({
    required this.question, required this.selection,
    required this.betAmount, required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final qId      = question['id']?.toString() ?? '';
    final text     = question['question_text'] ?? question['question'] ?? '';
    final emoji    = question['emoji'] ?? '🏏';
    final rawOpts  = (question['options'] is String
        ? json.decode(question['options'] as String)
        : question['options'] ?? []) as List;
    final opts     = rawOpts.cast<Map<String, dynamic>>();
    final status   = question['status'] ?? 'open';
    final userBet  = question['user_bet'] as Map<String, dynamic>?;
    final isLocked = status != 'open' || userBet != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SGColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(
            fontSize: 15, fontWeight: FontWeight.w700, color: SGColors.textPrimary,
          ))),
          if (status != 'open')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(status.toUpperCase(), style: const TextStyle(
                fontSize: 10, fontWeight: FontWeight.w800, color: SGColors.textMuted, letterSpacing: 0.8,
              )),
            ),
        ]),
        const SizedBox(height: 12),

        if (userBet != null)
          _UserBetBadge(bet: userBet)
        else
          Wrap(
            spacing: 8, runSpacing: 8,
            children: opts.map((opt) {
              final optId   = opt['id']?.toString() ?? '';
              final label   = opt['label'] ?? '';
              final odds    = (opt['odds'] ?? 2.0).toDouble();
              final picked  = selection?.optionId == optId;
              return GestureDetector(
                onTap: isLocked ? null : () {
                  HapticFeedback.selectionClick();
                  onSelect(qId, picked ? null : _Selection(
                    optionId: optId, optionLabel: label, odds: odds, coins: betAmount,
                  ));
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: picked ? const Color(0xFF00E5A8).withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: picked ? const Color(0xFF00E5A8).withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Column(children: [
                    Text(label, style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700,
                      color: picked ? const Color(0xFF00E5A8) : SGColors.textPrimary,
                    )),
                    const SizedBox(height: 2),
                    Text('${odds}x pts', style: const TextStyle(fontSize: 11, color: SGColors.textMuted)),
                  ]),
                ),
              );
            }).toList(),
          ),
      ]),
    );
  }
}

class _UserBetBadge extends StatelessWidget {
  final Map<String, dynamic> bet;
  const _UserBetBadge({required this.bet});

  @override
  Widget build(BuildContext context) {
    final status = bet['status'] as String? ?? 'pending';
    final color  = status == 'won'     ? const Color(0xFF22C55E)
                 : status == 'lost'    ? Colors.redAccent
                 : const Color(0xFF00E5A8);
    final icon   = status == 'won'     ? Icons.check_circle_rounded
                 : status == 'lost'    ? Icons.cancel_rounded
                 : Icons.lock_clock_rounded;
    final label  = bet['option_label'] ?? bet['option_id'] ?? '';
    final coins  = bet['coins'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(
          'Your pick: $label ($coins pts)${status == 'won' ? ' ✓ Won!' : status == 'lost' ? ' ✗' : ''}',
          style: TextStyle(fontSize: 12, color: color),
        )),
      ]),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.psychology_outlined, size: 48, color: SGColors.textMuted),
      const SizedBox(height: 12),
      Text(error, style: const TextStyle(color: SGColors.textMuted)),
      const SizedBox(height: 16),
      TextButton(onPressed: onRetry, child: const Text('Retry')),
    ],
  ));
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onRetry;
  const _EmptyState({required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.timer_outlined, size: 48, color: SGColors.textMuted),
      const SizedBox(height: 12),
      const Text('Predictions open before match start', style: TextStyle(color: SGColors.textMuted, fontSize: 14)),
      const SizedBox(height: 6),
      const Text('Check back soon!', style: TextStyle(color: SGColors.textMuted, fontSize: 12)),
      const SizedBox(height: 16),
      TextButton(onPressed: onRetry, child: const Text('Refresh')),
    ],
  ));
}

// ── Data class ────────────────────────────────────────────────────────────────

class _Selection {
  final String optionId;
  final String optionLabel;
  final double odds;
  final int    coins;
  const _Selection({
    required this.optionId, required this.optionLabel,
    required this.odds,     required this.coins,
  });
}
