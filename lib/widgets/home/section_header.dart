import 'package:flutter/material.dart';
import '../../theme.dart';

class SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Lighter, airier variant: medium-weight title and the icon set inside a
  /// soft milky rounded badge. Defaults to the original bold treatment so only
  /// the screens that opt in change.
  final bool fresh;

  const SectionHeader({
    super.key,
    required this.icon,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.fresh = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        CluvoTheme.screenPadding,
        fresh ? 2 : 0,
        CluvoTheme.screenPadding - 8,
        fresh ? 2 : 0,
      ),
      child: Row(
        children: [
          if (fresh)
            _iconBadge()
          else
            Icon(icon, size: 18, color: CluvoTheme.primary),
          SizedBox(width: fresh ? 12 : 8),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: fresh ? 17 : 20,
                fontWeight: fresh ? FontWeight.w600 : FontWeight.w800,
                letterSpacing: fresh ? -0.1 : -0.3,
                color: context.cluvoTextPrimary,
              ),
            ),
          ),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: CluvoTheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                actionLabel!.toLowerCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: fresh ? FontWeight.w500 : FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _iconBadge() {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: CluvoTheme.milkyFill,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: CluvoTheme.borderLavender,
          width: CluvoTheme.hairline,
        ),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 17, color: CluvoTheme.primary),
    );
  }
}
