import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/models.dart';
import '../../providers/community_provider.dart';
import '../../supabase_client.dart';
import '../../theme.dart';

/// Join / leave control backed by real membership state. Shows meaningful
/// success and error feedback, never silently swallows failures, and refreshes
/// the confirmed membership + database-maintained member count afterwards.
class CommunityJoinButton extends ConsumerStatefulWidget {
  final Community community;
  final bool expanded;

  /// When true the button sits over a photographic card, so it switches to a
  /// white treatment that stays legible on the dark scrim and renders compact.
  final bool onImage;

  const CommunityJoinButton({
    super.key,
    required this.community,
    this.expanded = false,
    this.onImage = false,
  });

  @override
  ConsumerState<CommunityJoinButton> createState() =>
      _CommunityJoinButtonState();
}

class _CommunityJoinButtonState extends ConsumerState<CommunityJoinButton> {
  bool _busy = false;

  Future<void> _toggle(bool isMember) async {
    if (_busy) return;
    final session = supabase.auth.currentSession;
    if (session == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to join a community.')),
      );
      context.push('/login');
      return;
    }

    setState(() => _busy = true);
    final service = ref.read(communityMembershipProvider);
    try {
      if (isMember) {
        await service.leave(widget.community.id);
      } else {
        await service.join(widget.community.id);
      }
      if (!mounted) return;
      ref.invalidate(myMembershipsProvider);
      ref.read(communitiesProvider.notifier).refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isMember
                ? 'Left ${widget.community.name}.'
                : 'Joined ${widget.community.name}!',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isMember
                ? 'Could not leave community. Please try again.'
                : 'Could not join community. Please try again.',
          ),
          backgroundColor: context.cluvoErrorText,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final memberships =
        ref.watch(myMembershipsProvider).valueOrNull ?? const [];
    final isMember = memberships.any(
      (m) => m.community.id == widget.community.id,
    );
    final onImage = widget.onImage;

    final spinnerColor = onImage
        ? (isMember ? Colors.white : CluvoTheme.textPrimaryColor)
        : (isMember ? CluvoTheme.primary : Colors.white);
    final child = _busy
        ? SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: spinnerColor,
            ),
          )
        : Text(
            isMember ? 'Joined' : 'Join',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          );

    return SizedBox(
      width: widget.expanded ? double.infinity : null,
      height: onImage ? 36 : 40,
      child: isMember
          ? OutlinedButton(
              onPressed: _busy ? null : () => _toggle(true),
              style: OutlinedButton.styleFrom(
                foregroundColor: onImage ? Colors.white : CluvoTheme.primary,
                side: BorderSide(
                  color: onImage ? Colors.white : CluvoTheme.primary,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(CluvoTheme.radiusButton),
                ),
              ),
              child: child,
            )
          : ElevatedButton(
              onPressed: _busy ? null : () => _toggle(false),
              style: ElevatedButton.styleFrom(
                backgroundColor: onImage ? Colors.white : CluvoTheme.primary,
                foregroundColor: onImage
                    ? CluvoTheme.textPrimaryColor
                    : Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                minimumSize: const Size(0, 36),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(CluvoTheme.radiusButton),
                ),
              ),
              child: child,
            ),
    );
  }
}
