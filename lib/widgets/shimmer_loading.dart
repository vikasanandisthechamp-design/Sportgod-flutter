import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

// ── Shared shimmer loading widgets ───────────────────────────────────────────
// Base color and highlight match the app's dark slate palette.

const _baseColor      = Color(0xFF1E293B);
const _highlightColor = Color(0xFF2D3B4F);

// ── ShimmerCard ──────────────────────────────────────────────────────────────

/// A single rounded rectangle shimmer placeholder.
class ShimmerCard extends StatelessWidget {
  final double height;
  final double? width;

  const ShimmerCard({super.key, required this.height, this.width});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: _baseColor,
      highlightColor: _highlightColor,
      child: Container(
        width: width ?? double.infinity,
        height: height,
        decoration: BoxDecoration(
          color: _baseColor,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

// ── ShimmerList ──────────────────────────────────────────────────────────────

/// Shows 5 shimmer cards stacked vertically — suitable for match lists.
class ShimmerList extends StatelessWidget {
  final int itemCount;

  const ShimmerList({super.key, this.itemCount = 5});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: _baseColor,
      highlightColor: _highlightColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: List.generate(itemCount, (i) => Padding(
            padding: EdgeInsets.only(bottom: i < itemCount - 1 ? 12 : 0),
            child: Container(
              width: double.infinity,
              height: 120,
              decoration: BoxDecoration(
                color: _baseColor,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          )),
        ),
      ),
    );
  }
}

// ── ShimmerMatchCard ─────────────────────────────────────────────────────────

/// Mimics the match card shape: header row, two team name rows with score
/// placeholders, and a note row.
class ShimmerMatchCard extends StatelessWidget {
  const ShimmerMatchCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: _baseColor,
      highlightColor: _highlightColor,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _baseColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Match type + status badge row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(width: 60, height: 10, decoration: BoxDecoration(color: _highlightColor, borderRadius: BorderRadius.circular(4))),
                Container(width: 40, height: 16, decoration: BoxDecoration(color: _highlightColor, borderRadius: BorderRadius.circular(10))),
              ],
            ),
            const SizedBox(height: 14),
            // Team row
            Row(
              children: [
                // Home team
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(width: 32, height: 32, decoration: BoxDecoration(color: _highlightColor, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Container(width: 50, height: 14, decoration: BoxDecoration(color: _highlightColor, borderRadius: BorderRadius.circular(4))),
                    ]),
                    const SizedBox(height: 6),
                    Container(width: 80, height: 18, decoration: BoxDecoration(color: _highlightColor, borderRadius: BorderRadius.circular(4))),
                  ],
                )),
                // vs
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Container(width: 16, height: 10, decoration: BoxDecoration(color: _highlightColor, borderRadius: BorderRadius.circular(4))),
                ),
                // Away team
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                      Container(width: 50, height: 14, decoration: BoxDecoration(color: _highlightColor, borderRadius: BorderRadius.circular(4))),
                      const SizedBox(width: 8),
                      Container(width: 32, height: 32, decoration: BoxDecoration(color: _highlightColor, shape: BoxShape.circle)),
                    ]),
                    const SizedBox(height: 6),
                    Container(width: 80, height: 18, decoration: BoxDecoration(color: _highlightColor, borderRadius: BorderRadius.circular(4))),
                  ],
                )),
              ],
            ),
            const SizedBox(height: 10),
            // Note row
            Container(width: double.infinity, height: 12, decoration: BoxDecoration(color: _highlightColor, borderRadius: BorderRadius.circular(4))),
          ],
        ),
      ),
    );
  }
}

// ── ShimmerProfile ──────────────────────────────────────────────────────────

/// Mimics the profile page layout: avatar + name card, stats row, menu items.
class ShimmerProfile extends StatelessWidget {
  const ShimmerProfile({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: _baseColor,
      highlightColor: _highlightColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // User card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _baseColor,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(children: [
                // Avatar circle
                Container(width: 56, height: 56, decoration: BoxDecoration(color: _highlightColor, shape: BoxShape.circle)),
                const SizedBox(width: 16),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: 160, height: 14, decoration: BoxDecoration(color: _highlightColor, borderRadius: BorderRadius.circular(4))),
                    const SizedBox(height: 8),
                    Container(width: 60, height: 18, decoration: BoxDecoration(color: _highlightColor, borderRadius: BorderRadius.circular(6))),
                  ],
                )),
              ]),
            ),
            const SizedBox(height: 16),
            // Stats row
            Container(
              height: 80,
              decoration: BoxDecoration(
                color: _baseColor,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            const SizedBox(height: 16),
            // Menu items
            ...List.generate(4, (i) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  color: _baseColor,
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            )),
          ],
        ),
      ),
    );
  }
}
