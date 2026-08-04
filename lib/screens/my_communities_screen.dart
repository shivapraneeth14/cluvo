import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme.dart';
import '../providers/community_provider.dart';
import '../widgets/list_page_scaffold.dart';
import '../models/community.dart';

Widget _letterAvatar(Community c) {
  return Center(
    child: Text(
      c.name.isNotEmpty ? c.name[0].toUpperCase() : 'C',
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: CluvoTheme.primary,
      ),
    ),
  );
}

class MyCommunitiesScreen extends ConsumerWidget {
  const MyCommunitiesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myCommunitiesProvider);

    return ListPageScaffold(
      title: 'My Communities',
      onRefresh: () async {
        ref.invalidate(myCommunitiesProvider);
        await ref.read(myCommunitiesProvider.future);
      },
      child: async.when(
        data: (communities) {
          if (communities.isEmpty) {
            return const EmptyState(
              icon: Icons.groups_outlined,
              message: "You haven't joined any communities yet.",
            );
          }
          return Column(
            children: [
              for (final c in communities)
                ActivityCard(
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: CluvoTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: c.communityAvatarUrl != null &&
                            c.communityAvatarUrl!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: c.communityAvatarUrl!,
                            fit: BoxFit.cover,
                            errorWidget: (_, _, _) => _letterAvatar(c),
                          )
                        : _letterAvatar(c),
                  ),
                  title: c.name,
                  subtitle: '${c.city ?? ''}${c.city != null && c.country != null ? ', ' : ''}${c.country ?? ''}',
                  trailing: Text(
                    '${c.memberCount} members',
                    style: TextStyle(
                      fontSize: 11,
                      color: context.cluvoTextSecondary,
                    ),
                  ),
                  onTap: () => context.push('/communities/${c.id}'),
                ),
            ],
          );
        },
        loading: () => const SizedBox(
          height: 120,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        error: (e, _) => Center(
          child: Text(
            'Could not load communities.',
            style: TextStyle(color: context.cluvoTextSecondary, fontSize: 13),
          ),
        ),
      ),
    );
  }
}