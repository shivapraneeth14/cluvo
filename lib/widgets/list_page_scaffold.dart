import 'package:flutter/material.dart';
import '../theme.dart';

/// Common layout for full-bleed list pages (My Communities / Registrations /
/// Payments): a solid app bar with back navigation + refreshable content.
class ListPageScaffold extends StatelessWidget {
  final String title;
  final Future<void> Function()? onRefresh;
  final Widget child;

  const ListPageScaffold({
    super.key,
    required this.title,
    this.onRefresh,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final body = ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [child],
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: context.cluvoBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: context.cluvoTextPrimary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
        ),
        centerTitle: false,
      ),
      body: onRefresh != null
          ? RefreshIndicator(onRefresh: onRefresh!, child: body)
          : body,
    );
  }
}

/// Common floating row card used across list pages and the profile menu.
class ActivityCard extends StatelessWidget {
  final Widget leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const ActivityCard({
    super.key,
    required this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.cluvoSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                leading,
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: context.cluvoTextPrimary,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: context.cluvoTextSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  trailing!,
                ],
                const SizedBox(width: 4),
                Icon(Icons.chevron_right, size: 20, color: context.cluvoTextSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Common empty-list placeholder.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const EmptyState({super.key, required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: context.cluvoTextSecondary),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.cluvoTextSecondary, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}