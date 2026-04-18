import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'settings_screen.dart';
import 'groups_screen.dart';
import 'song_detail_screen.dart';
import '../providers/spotify_provider.dart';
import '../services/firestore_service.dart';

final _homeGroupsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final userId = ref.watch(userProvider).value?['id'] as String?;
  if (userId == null) return [];
  return FirestoreService().getGroupsForUser(userId);
});

// Real-time stream so the list disappears automatically once the user votes.
final _pendingVotesProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final userId = ref.watch(userProvider).value?['id'] as String?;
  if (userId == null) return Stream.value([]);

  // Watch synchronously — provider rebuilds when groups finish loading.
  final groups = ref.watch(_homeGroupsProvider).value ?? [];
  final groupIds = groups
      .map((g) => g['id'] as String? ?? '')
      .where((id) => id.isNotEmpty)
      .toList();
  if (groupIds.isEmpty) return const Stream.empty();

  return FirebaseFirestore.instance
      .collection('pendingVotes')
      .where('groupId', whereIn: groupIds.take(30).toList())
      .where('status', isEqualTo: 'pending')
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => <String, dynamic>{'id': doc.id, ...doc.data()})
          .where((vote) {
            final ratings = vote['ratings'];
            return !(ratings is Map && ratings.containsKey(userId));
          })
          .toList());
});

// Watches groups synchronously to avoid depending on .future (which can
// cause indefinite loading). Sorts client-side so no composite index needed.
final _recentActivityProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final userId = ref.watch(userProvider).value?['id'] as String?;
  if (userId == null) return [];

  final groups = ref.watch(_homeGroupsProvider).value ?? [];
  final groupIds = groups
      .map((g) => g['id'] as String? ?? '')
      .where((id) => id.isNotEmpty)
      .toList();
  if (groupIds.isEmpty) return [];

  // No orderBy — avoids the composite index requirement on groupId + status + proposedAt.
  final snapshot = await FirebaseFirestore.instance
      .collection('pendingVotes')
      .where('groupId', whereIn: groupIds.take(30).toList())
      .where('status', whereIn: ['accepted', 'rejected'])
      .limit(50)
      .get();

  final results = snapshot.docs
      .map((doc) => <String, dynamic>{'id': doc.id, ...doc.data()})
      .toList()
    ..sort((a, b) {
      final aTs = a['proposedAt'] as Timestamp?;
      final bTs = b['proposedAt'] as Timestamp?;
      if (aTs == null && bTs == null) return 0;
      if (aTs == null) return 1;
      if (bTs == null) return -1;
      return bTs.compareTo(aTs);
    });

  return results.take(10).toList();
});

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProvider);
    final profileImageUrl =
        userAsync.value?['images']?.first?['url'] as String?;
    final groupsAsync = ref.watch(_homeGroupsProvider);
    final pendingAsync = ref.watch(_pendingVotesProvider);
    final activityAsync = ref.watch(_recentActivityProvider);

    // Build a groupId → name lookup from already-loaded groups
    final groupNameMap = Map.fromEntries(
      (groupsAsync.value ?? []).map((g) => MapEntry(
            g['id'] as String? ?? '',
            g['name'] as String? ?? 'Unknown Group',
          )),
    );

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        leading: GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFF535353),
              backgroundImage: profileImageUrl != null
                  ? NetworkImage(profileImageUrl)
                  : null,
              child: profileImageUrl == null
                  ? const Icon(Icons.person, color: Colors.white)
                  : null,
            ),
          ),
        ),
        title: const Text(
          'Home',
          style: TextStyle(
              color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Greeting ────────────────────────────────────────────────────
            userAsync.when(
              loading: () => const SizedBox(
                height: 36,
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Color(0xFF1DB954)),
                  ),
                ),
              ),
              error: (_, __) => const Text(
                'Hey there 👋',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold),
              ),
              data: (user) => Text(
                'Hey ${user['display_name'] ?? 'there'} 👋',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 28),

            // ── Pending Votes ────────────────────────────────────────────────
            const Text(
              'Pending Votes',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            pendingAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: CircularProgressIndicator(color: Color(0xFF1DB954)),
                ),
              ),
              error: (e, _) => _emptyBox(
                  'Could not load pending votes', isError: true),
              data: (votes) {
                if (votes.isEmpty) {
                  return _emptyBox('No pending votes 🎉',
                      subtitle: "You're all caught up");
                }
                return Column(
                  children: votes.map((vote) {
                    final voteId = vote['id'] as String? ?? '';
                    final songName =
                        vote['songName'] as String? ?? 'Unknown';
                    final artistName =
                        vote['artistName'] as String? ?? '';
                    final albumArt = vote['albumArt'] as String?;
                    final groupId = vote['groupId'] as String? ?? '';
                    final groupName =
                        groupNameMap[groupId] ?? 'Unknown Group';

                    final track = {
                      'id': vote['songId'] as String? ?? '',
                      'name': songName,
                      'artists': [
                        {'name': artistName}
                      ],
                      'album': {
                        'images': albumArt != null && albumArt.isNotEmpty
                            ? [
                                {'url': albumArt}
                              ]
                            : <Map>[]
                      },
                    };

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(14),
                        border:
                            Border.all(color: const Color(0xFF2A2A2A)),
                      ),
                      child: Row(
                        children: [
                          // Album art
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: albumArt != null && albumArt.isNotEmpty
                                ? Image.network(
                                    albumArt,
                                    width: 48,
                                    height: 48,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        _artPlaceholder(),
                                  )
                                : _artPlaceholder(),
                          ),
                          const SizedBox(width: 12),
                          // Song + group info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  songName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (artistName.isNotEmpty)
                                  Text(
                                    artistName,
                                    style: const TextStyle(
                                        color: Colors.grey, fontSize: 12),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                Text(
                                  groupName,
                                  style: const TextStyle(
                                      color: Color(0xFF1DB954),
                                      fontSize: 11),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Rate Now button
                          SizedBox(
                            height: 32,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1DB954),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                textStyle: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600),
                                elevation: 0,
                              ),
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => SongDetailScreen(
                                    track: track,
                                    pendingVoteId: voteId,
                                  ),
                                ),
                              ),
                              child: const Text('Rate Now'),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 32),

            // ── Recent Activity ──────────────────────────────────────────────
            const Text(
              'Recent Activity',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            activityAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: CircularProgressIndicator(color: Color(0xFF1DB954)),
                ),
              ),
              error: (e, _) =>
                  _emptyBox('Could not load activity', isError: true),
              data: (items) {
                if (items.isEmpty) {
                  return _emptyBox('No activity yet');
                }
                return Column(
                  children: items.map((item) {
                    final songName =
                        item['songName'] as String? ?? 'Unknown';
                    final artistName =
                        item['artistName'] as String? ?? '';
                    final albumArt = item['albumArt'] as String?;
                    final status =
                        item['status'] as String? ?? 'rejected';
                    final accepted = status == 'accepted';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(14),
                        border:
                            Border.all(color: const Color(0xFF2A2A2A)),
                      ),
                      child: Row(
                        children: [
                          // Album art
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: albumArt != null && albumArt.isNotEmpty
                                ? Image.network(
                                    albumArt,
                                    width: 44,
                                    height: 44,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        _artPlaceholder(),
                                  )
                                : _artPlaceholder(),
                          ),
                          const SizedBox(width: 12),
                          // Song info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  songName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (artistName.isNotEmpty)
                                  Text(
                                    artistName,
                                    style: const TextStyle(
                                        color: Colors.grey, fontSize: 12),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Status badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: accepted
                                  ? const Color(0xFF1DB954).withOpacity(0.15)
                                  : Colors.red.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              accepted
                                  ? '✓ Added to playlist'
                                  : '✗ Rejected',
                              style: TextStyle(
                                color: accepted
                                    ? const Color(0xFF1DB954)
                                    : Colors.red,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 32),

            // ── Your Groups ──────────────────────────────────────────────────
            const Text(
              'Your Groups',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            groupsAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: CircularProgressIndicator(
                      color: Color(0xFF1DB954)),
                ),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text('Error: $e',
                    style: const TextStyle(color: Colors.grey)),
              ),
              data: (groups) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (groups.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          vertical: 28, horizontal: 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(16),
                        border:
                            Border.all(color: const Color(0xFF2A2A2A)),
                      ),
                      child: const Text(
                        'No groups yet',
                        style:
                            TextStyle(color: Colors.grey, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    ...groups.map((group) {
                      final name = group['name'] as String? ?? '';
                      final inviteCode =
                          group['inviteCode'] as String? ?? '';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                            vertical: 14, horizontal: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: const Color(0xFF2A2A2A)),
                        ),
                        child: Row(
                          children: [
                            const CircleAvatar(
                              radius: 20,
                              backgroundColor: Color(0xFF1DB954),
                              child: Icon(Icons.group,
                                  color: Colors.white, size: 20),
                            ),
                            const SizedBox(width: 14),
                            Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  inviteCode,
                                  style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                  const SizedBox(height: 4),
                  TextButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const GroupsScreen()),
                    ),
                    icon: const Icon(Icons.add,
                        color: Color(0xFF1DB954), size: 18),
                    label: const Text(
                      'Create Group',
                      style: TextStyle(
                          color: Color(0xFF1DB954), fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _emptyBox(String message,
      {String? subtitle, bool isError = false}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(
        children: [
          Text(
            message,
            style: TextStyle(
              color: isError ? Colors.grey : Colors.white,
              fontSize: isError ? 14 : 16,
              fontWeight:
                  isError ? FontWeight.normal : FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _artPlaceholder() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFF212121),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Icon(Icons.music_note, color: Colors.grey, size: 22),
    );
  }
}
