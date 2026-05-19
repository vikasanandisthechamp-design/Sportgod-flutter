import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/coins_provider.dart';
import 'home_screen.dart';
import 'matches_screen.dart';
import 'games_screen.dart';
import 'profile_screen.dart';

class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int _index = 0;

  final _screens = const [
    HomeScreen(),
    MatchesScreen(),
    GamesScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      final coins = context.read<CoinsProvider>();
      coins.sync(auth.accessToken);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0F0F11),
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 60,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _navItem(Icons.home_rounded, 'Home', 0),
                _navItem(Icons.sports_cricket_rounded, 'Matches', 1),
                _navItem(Icons.emoji_events_rounded, 'Games', 2),
                _navItem(Icons.person_rounded, 'Profile', 3),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int idx) {
    final active = _index == idx;
    return Semantics(
      label: '$label tab${active ? ", selected" : ""}',
      button: true,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() => _index = idx);
        },
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 72,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 24,
                color: active ? const Color(0xFF00E5A8) : Colors.white.withValues(alpha: 0.4)),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(
                fontSize: 10,
                fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                color: active ? const Color(0xFF00E5A8) : Colors.white.withValues(alpha: 0.4),
              )),
            ],
          ),
        ),
      ),
    );
  }
}
