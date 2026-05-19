import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';

/// Pre-defined avatar options the user can pick from.
const _avatarOptions = [
  '\u{1F3CF}', // cricket bat
  '\u{1F3C6}', // trophy
  '\u{26BD}',  // soccer ball
  '\u{1F525}', // fire
  '\u{1F680}', // rocket
  '\u{1F60E}', // cool face
  '\u{1F981}', // lion
  '\u{1F40D}', // snake
];

/// IPL team shortcodes for the multi-select chips.
const _iplTeams = [
  'CSK', 'MI', 'RCB', 'KKR', 'DC',
  'PBKS', 'SRH', 'RR', 'GT', 'LSG',
];

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();

  String _selectedAvatar = _avatarOptions.first;
  List<String> _selectedTeams = [];

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Load
  // ---------------------------------------------------------------------------

  Future<void> _loadProfile() async {
    final db = Supabase.instance.client;
    final userId = db.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final res = await db
          .from('users')
          .select('display_name, avatar_url, bio, favorite_teams')
          .eq('id', userId)
          .maybeSingle();

      if (res != null) {
        _nameCtrl.text = (res['display_name'] as String?) ?? '';
        _bioCtrl.text = (res['bio'] as String?) ?? '';

        final avatar = res['avatar_url'] as String?;
        if (avatar != null && _avatarOptions.contains(avatar)) {
          _selectedAvatar = avatar;
        }

        final teams = res['favorite_teams'];
        if (teams is List) {
          _selectedTeams = teams.cast<String>().toList();
        }
      }
    } catch (_) {
      // Silently fall back to defaults.
    }

    if (mounted) setState(() => _loading = false);
  }

  // ---------------------------------------------------------------------------
  // Save
  // ---------------------------------------------------------------------------

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    final db = Supabase.instance.client;
    final userId = db.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await db.from('users').update({
        'display_name': _nameCtrl.text.trim(),
        'avatar_url': _selectedAvatar,
        'bio': _bioCtrl.text.trim(),
        'favorite_teams': _selectedTeams,
      }).eq('id', userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated!'),
            backgroundColor: Color(0xFF00E5A8),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Save failed: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Input decoration (matches login screen style)
  // ---------------------------------------------------------------------------

  InputDecoration _inputDecor(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: SGColors.textMuted),
      prefixIcon: Icon(icon, color: SGColors.textMuted, size: 20),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.05),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF00E5A8)),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00E5A8)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Display name ────────────────────────────────────
                    const _SectionLabel('Display Name'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _nameCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                      decoration: _inputDecor('Your display name', Icons.person_outline),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Name is required';
                        return null;
                      },
                    ),

                    const SizedBox(height: 24),

                    // ── Avatar selection ─────────────────────────────────
                    const _SectionLabel('Avatar'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                      decoration: BoxDecoration(
                        color: SGColors.card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: _avatarOptions.map((emoji) {
                          final selected = emoji == _selectedAvatar;
                          return GestureDetector(
                            onTap: () => setState(() => _selectedAvatar = emoji),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: selected
                                    ? const Color(0xFF00E5A8).withValues(alpha: 0.2)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                border: selected
                                    ? Border.all(color: const Color(0xFF00E5A8), width: 2)
                                    : null,
                              ),
                              alignment: Alignment.center,
                              child: Text(emoji, style: const TextStyle(fontSize: 22)),
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Bio ──────────────────────────────────────────────
                    const _SectionLabel('Bio'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _bioCtrl,
                      maxLength: 120,
                      maxLines: 3,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                      decoration: _inputDecor('A little about you...', Icons.edit_note_outlined),
                    ),

                    const SizedBox(height: 24),

                    // ── Preferred teams ──────────────────────────────────
                    const _SectionLabel('Preferred Teams'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _iplTeams.map((team) {
                        final selected = _selectedTeams.contains(team);
                        return FilterChip(
                          label: Text(team),
                          selected: selected,
                          onSelected: (on) {
                            setState(() {
                              if (on) {
                                _selectedTeams.add(team);
                              } else {
                                _selectedTeams.remove(team);
                              }
                            });
                          },
                          selectedColor: const Color(0xFF00E5A8).withValues(alpha: 0.2),
                          checkmarkColor: const Color(0xFF00E5A8),
                          backgroundColor: SGColors.card,
                          side: BorderSide(
                            color: selected
                                ? const Color(0xFF00E5A8)
                                : Colors.white.withValues(alpha: 0.1),
                          ),
                          labelStyle: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: selected ? const Color(0xFF00E5A8) : SGColors.textSecondary,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 36),

                    // ── Save button ──────────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF00E5A8), Color(0xFF00C9FF)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: ElevatedButton(
                          onPressed: _saving ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: _saving
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.black,
                                  ),
                                )
                              : const Text(
                                  'Save Changes',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F0F11),
                                  ),
                                ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }
}

// Small reusable label widget used by the form sections above.
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: SGColors.textSecondary,
        letterSpacing: 0.3,
      ),
    );
  }
}
