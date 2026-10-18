import 'package:flutter/material.dart';
import '../../theme.dart';

class SearchSegment {
  final String label;
  final IconData icon;

  const SearchSegment({required this.label, required this.icon});
}

/// Pill track with a sliding gradient indicator driving a [TabController].
/// Follows both taps (via `animateTo`) and swipes (via `controller.animation`).
class SearchSegmentedTabs extends StatelessWidget {
  final TabController controller;
  final List<SearchSegment> segments;

  const SearchSegmentedTabs({
    super.key,
    required this.controller,
    required this.segments,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const pad = 4.0;
        final inner = constraints.maxWidth - pad * 2;
        final segWidth = inner / segments.length;

        return Container(
          height: 46,
          padding: const EdgeInsets.all(pad),
          decoration: BoxDecoration(
            color: context.cluvoChipFill,
            borderRadius: BorderRadius.circular(CluvoTheme.radiusPill),
            border: Border.all(color: context.cluvoBorder),
          ),
          child: AnimatedBuilder(
            animation: controller.animation ?? controller,
            builder: (context, _) {
              final value =
                  controller.animation?.value ?? controller.index.toDouble();
              return Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    left: value * segWidth,
                    top: 0,
                    bottom: 0,
                    width: segWidth,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: CluvoTheme.primaryCtaGradient,
                        borderRadius: BorderRadius.circular(
                          CluvoTheme.radiusPill,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (var i = 0; i < segments.length; i++)
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => controller.animateTo(i),
                            child: _segmentContent(context, i, value),
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _segmentContent(BuildContext context, int index, double value) {
    final active = (value - index).abs() < 0.5;
    final color = active ? Colors.white : context.cluvoTextSecondary;
    final segment = segments[index];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(segment.icon, size: 17, color: color),
        const SizedBox(width: 7),
        Text(
          segment.label,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
