import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/coins_provider.dart';
import '../theme/app_theme.dart';
import 'edit_profile_screen.dart';
import 'history_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final coins = context.watch<CoinsProvider>();
    final user = auth.user;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // User card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: SGColors.card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: const Color(0xFF00E5A8).withValues(alpha: 0.15),
                child: Text(
                  (user?.email?.substring(0, 1) ?? 'U').toUpperCase(),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF00E5A8)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user?.email ?? 'User',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: SGColors.textPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: auth.isPremium
                          ? const Color(0xFFA78BFA).withValues(alpha: 0.15)
                          : const Color(0xFF00E5A8).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      auth.isPremium ? 'PRO' : 'FREE',
                      style: TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w800,
                        color: auth.isPremium ? const Color(0xFFA78BFA) : const Color(0xFF00E5A8),
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
              )),
              IconButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                ),
                icon: const Icon(Icons.edit_outlined, color: SGColors.textMuted, size: 20),
                tooltip: 'Edit Profile',
              ),
            ]),
          ),
          const SizedBox(height: 16),

          // Points card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF1C1C21), Color(0xFF252530)]),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(children: [
              Row(children: [
                const Icon(Icons.stars_rounded, size: 28, color: Color(0xFFFFD700)),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('SG Points', style: TextStyle(fontSize: 12, color: SGColors.textMuted)),
                    const SizedBox(height: 2),
                    Text(
                      '${coins.balance}',
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFFFFD700)),
                    ),
                  ],
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => coins.sync(auth.accessToken),
                  icon: const Icon(Icons.refresh_rounded, color: SGColors.textMuted, size: 20),
                ),
              ]),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(children: [
                  Icon(Icons.info_outline_rounded, size: 14, color: SGColors.textMuted.withValues(alpha: 0.6)),
                  const SizedBox(width: 6),
                  const Expanded(child: Text(
                    'Virtual points for games only. No real-money value. Cannot be redeemed or exchanged.',
                    style: TextStyle(fontSize: 10, color: SGColors.textMuted, fontStyle: FontStyle.italic, height: 1.3),
                  )),
                ]),
              ),
            ]),
          ),
          // Premium CTA (only shown to non-premium users)
          if (!auth.isPremium) ...[
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () => context.push('/premium'),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6C3CF7), Color(0xFF00C9FF)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(children: [
                  const Text('⚡', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 12),
                  const Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Upgrade to PRO', style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white,
                      )),
                      SizedBox(height: 2),
                      Text('Unlimited AI chat, advanced predictions & more', style: TextStyle(
                        fontSize: 11, color: Colors.white70,
                      )),
                    ],
                  )),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('₹299/yr', style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF6C3CF7),
                    )),
                  ),
                ]),
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Menu items
          _menuItem(context, Icons.chat_bubble_rounded, 'SportsGPT Chat', 'Ask AI anything about cricket', () {
            context.push('/chat');
          }),
          _menuItem(context, Icons.history_rounded, 'Game History', 'View past predictions & fantasy picks', () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryScreen()));
          }),
          _menuItem(context, Icons.leaderboard_rounded, 'Global Leaderboard', 'Top players this season', () {
            context.push('/leaderboard');
          }),

          const SizedBox(height: 16),

          // Legal section header
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text('LEGAL', style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w800, color: SGColors.textMuted, letterSpacing: 1.2,
            )),
          ),
          _menuItem(context, Icons.privacy_tip_outlined, 'Privacy Policy', 'How we handle your data', () {
            context.push('/privacy');
          }),
          _menuItem(context, Icons.description_outlined, 'Terms of Service', 'Rules and guidelines', () {
            context.push('/terms');
          }),
          _menuItem(context, Icons.info_outline_rounded, 'About', 'SportGod AI v1.0', () {
            showAboutDialog(
              context: context,
              applicationName: 'SportGod AI',
              applicationVersion: '1.0.0',
              applicationLegalese: '© 2025 SportGod AI. All rights reserved.\n\nVirtual points only. No real money.',
              children: [
                const SizedBox(height: 12),
                const Text(
                  'The AI-powered super scoreboard for cricket fans — live scores, fantasy, predictions and more.',
                  style: TextStyle(fontSize: 13, height: 1.4),
                ),
              ],
            );
          }),

          const SizedBox(height: 24),

          // Anti-gambling statement
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF22C55E).withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.1)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.volunteer_activism_rounded, size: 18, color: const Color(0xFF22C55E).withValues(alpha: 0.7)),
              const SizedBox(width: 10),
              Expanded(child: Text(
                'SportGod AI promotes skill-based sports engagement as a healthy alternative to gambling. '
                'No real money is involved anywhere in this app.',
                style: TextStyle(fontSize: 11, color: const Color(0xFF22C55E).withValues(alpha: 0.8), height: 1.4),
              )),
            ]),
          ),

          const SizedBox(height: 16),

          // Sign out
          TextButton.icon(
            onPressed: () => auth.signOut(),
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('Sign Out'),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _menuItem(BuildContext context, IconData icon, String title, String subtitle, VoidCallback? onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: SGColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: const Color(0xFF00E5A8), size: 22),
        title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: SGColors.textPrimary)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: SGColors.textMuted)),
        trailing: const Icon(Icons.chevron_right_rounded, color: SGColors.textMuted, size: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
