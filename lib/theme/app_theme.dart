import 'package:flutter/material.dart';

class SGColors {
  // Brand
  static const primary   = Color(0xFF6366F1); // Indigo
  static const surface   = Color(0xFF1E293B); // Slate-800
  static const bg        = Color(0xFF0F172A); // Slate-950
  static const card      = Color(0xFF1E293B); // Slate-800

  // Status
  static const live      = Color(0xFFEF4444); // Red
  static const boundary  = Color(0xFF3B82F6); // Blue
  static const six       = Color(0xFFA855F7); // Purple
  static const wicket    = Color(0xFFEF4444); // Red
  static const good      = Color(0xFF22C55E); // Green
  static const warn      = Color(0xFFF59E0B); // Amber

  // Text
  static const textPrimary   = Color(0xFFF1F5F9); // Slate-100
  static const textSecondary = Color(0xFF94A3B8); // Slate-400
  static const textMuted     = Color(0xFF475569); // Slate-600
}

class AppTheme {
  static ThemeData get dark => ThemeData(
    brightness:   Brightness.dark,
    useMaterial3: true,
    colorScheme:  const ColorScheme.dark(
      primary:    SGColors.primary,
      surface:    SGColors.surface,
    ),
    scaffoldBackgroundColor: SGColors.bg,
    cardTheme: CardTheme(
      color:       SGColors.card,
      elevation:   0,
      shape:       RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.08), width: 1),
      ),
      margin: EdgeInsets.zero,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor:  SGColors.bg,
      surfaceTintColor: Colors.transparent,
      elevation:        0,
      centerTitle:      false,
      titleTextStyle: TextStyle(
        color:      SGColors.textPrimary,
        fontSize:   18,
        fontWeight: FontWeight.w700,
      ),
      iconTheme: IconThemeData(color: SGColors.textPrimary),
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(color: SGColors.textPrimary, fontWeight: FontWeight.w800),
      headlineMedium:TextStyle(color: SGColors.textPrimary, fontWeight: FontWeight.w700),
      titleLarge:    TextStyle(color: SGColors.textPrimary, fontWeight: FontWeight.w600),
      titleMedium:   TextStyle(color: SGColors.textPrimary, fontWeight: FontWeight.w500),
      bodyLarge:     TextStyle(color: SGColors.textPrimary),
      bodyMedium:    TextStyle(color: SGColors.textSecondary),
      bodySmall:     TextStyle(color: SGColors.textMuted,   fontSize: 12),
    ),
    tabBarTheme: const TabBarTheme(
      labelColor:        SGColors.textPrimary,
      unselectedLabelColor: SGColors.textMuted,
      indicatorColor:    SGColors.primary,
      indicatorSize:     TabBarIndicatorSize.tab,
    ),
    dividerTheme: DividerThemeData(
      color:     Colors.white.withValues(alpha: 0.08),
      thickness: 1,
      space:     1,
    ),
  );
}

// ── Common widget helpers ─────────────────────────────────────────────

class SGCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final VoidCallback? onTap;

  const SGCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap:        onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: padding ?? const EdgeInsets.all(16),
          child:   child,
        ),
      ),
    );
  }
}

class BallBadge extends StatelessWidget {
  final String label;

  const BallBadge({super.key, required this.label});

  String get _semanticLabel {
    switch (label) {
      case 'W':  return 'Wicket';
      case '6':  return 'Six runs';
      case '4':  return 'Four runs';
      case 'WD': return 'Wide ball';
      case 'NB': return 'No ball';
      default:   return '$label runs';
    }
  }

  @override
  Widget build(BuildContext context) {
    Color bg = SGColors.textMuted;
    if (label == 'W') {
      bg = SGColors.wicket;
    } else if (label == '6') {
      bg = SGColors.six;
    } else if (label == '4') {
      bg = SGColors.boundary;
    } else if (label == 'WD' || label == 'NB') {
      bg = SGColors.warn;
    }

    return Semantics(
      label: _semanticLabel,
      child: Container(
      width: 32, height: 32,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          color:      Colors.white,
          fontSize:   11,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
    );
  }
}
