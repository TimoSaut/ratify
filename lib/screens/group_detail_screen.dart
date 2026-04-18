import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import 'search_screen.dart';
import '../providers/spotify_provider.dart';
import '../providers/auth_provider.dart';
import '../services/firestore_service.dart';
import '../services/spotify_service.dart';

// ── Providers ──────────────────────────────────────────────────────────────────

final _groupDetailProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>?, String>((ref, groupId) async {
  final doc = await FirebaseFirestore.instance
      .collection('groups')
      .doc(groupId)
      .get();
  if (!doc.exists) return null;
  return {'id': doc.id, ...doc.data()!};
});

final _playlistTracksProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, playlistId) async {
  if (playlistId.isEmpty) return [];
  final authService = ref.read(authServiceProvider);
  return SpotifyService(authService: authService).getPlaylistTracks(playlistId);
});

final _pendingVotesForGroupProvider = StreamProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, groupId) {
  if (groupId.isEmpty) return const Stream.empty();
  return FirebaseFirestore.instance
      .collection('pendingVotes')
      .where('groupId', isEqualTo: groupId)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList());
});

// ── Screen ─────────────────────────────────────────────────────────────────────

class GroupDetailScreen extends ConsumerWidget {
  final String groupId;
  final String playlistName;
  final String? coverUrl;

  const GroupDetailScreen({
    super.key,
    required this.groupId,
    required this.playlistName,
    this.coverUrl,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupAsync = ref.watch(_groupDetailProvider(groupId));
    final userId = ref.watch(userProvider).value?['id'] as String?;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(
          playlistName,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh songs',
            onPressed: () {
              final playlistId =
                  groupAsync.value?['spotifyPlaylistId'] as String? ?? '';
              if (playlistId.isNotEmpty) {
                ref.invalidate(_playlistTracksProvider(playlistId));
              }
            },
          ),
        ],
      ),
      body: groupAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFF1DB954)),
        ),
        error: (e, _) => Center(
          child: Text('Error: $e',
              style: const TextStyle(color: Colors.grey)),
        ),
        data: (group) {
          if (group == null) {
            return const Center(
              child: Text('Group not found',
                  style: TextStyle(color: Colors.grey)),
            );
          }
          return _GroupDetailBody(group: group, userId: userId, coverUrl: coverUrl);
        },
      ),
    );
  }
}

// ── Body ───────────────────────────────────────────────────────────────────────

class _GroupDetailBody extends ConsumerWidget {
  final Map<String, dynamic> group;
  final String? userId;
  final String? coverUrl;

  const _GroupDetailBody({required this.group, required this.userId, this.coverUrl});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = group['name'] as String? ?? 'Untitled';
    final groupId = group['id'] as String? ?? '';
    final members = (group['members'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    final inviteCode = group['inviteCode'] as String? ?? '';
    final spotifyPlaylistId = group['spotifyPlaylistId'] as String? ?? '';

    final tracksAsync = ref.watch(_playlistTracksProvider(spotifyPlaylistId));
    final votesAsync = ref.watch(_pendingVotesForGroupProvider(groupId));

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      children: [
        // ── Header ─────────────────────────────────────────────────────────
        _PlaylistHeader(
          name: name,
          memberCount: members.length,
          coverUrl: group['coverUrl'] as String? ?? coverUrl,
        ),
        const SizedBox(height: 16),

        // ── Propose a Song ─────────────────────────────────────────────────
        _ProposeSongButton(
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SearchScreen(groupId: groupId),
              ),
            );
            ref.invalidate(_playlistTracksProvider(spotifyPlaylistId));
          },
        ),
        const SizedBox(height: 28),

        // ── Members ────────────────────────────────────────────────────────
        _sectionTitle('Members'),
        const SizedBox(height: 12),
        _MembersRow(members: members),
        const SizedBox(height: 12),
        _InviteButton(inviteCode: inviteCode),
        const SizedBox(height: 28),

        // ── Songs in Playlist ──────────────────────────────────────────────
        _sectionTitle('Songs in Playlist'),
        const SizedBox(height: 12),
        _buildTracksSection(tracksAsync, spotifyPlaylistId),
        const SizedBox(height: 28),

        // ── Pending Votes ──────────────────────────────────────────────────
        _sectionTitle('Pending Votes'),
        const SizedBox(height: 12),
        _buildVotesSection(votesAsync, userId),
        const SizedBox(height: 28),

        // ── Leave Group ────────────────────────────────────────────────────
        if (userId != null)
          _LeaveGroupButton(groupId: groupId, userId: userId!),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 17,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _emptyCard(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: const TextStyle(color: Colors.grey, fontSize: 14),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildTracksSection(
    AsyncValue<List<Map<String, dynamic>>> tracksAsync,
    String spotifyPlaylistId,
  ) {
    if (spotifyPlaylistId.isEmpty) {
      return _emptyCard('No Spotify playlist linked');
    }
    return tracksAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
            child: CircularProgressIndicator(color: Color(0xFF1DB954))),
      ),
      error: (e, _) => _emptyCard('Could not load songs'),
      data: (items) {
        final validItems = items
            .where((item) => item['track'] != null)
            .toList();
        if (validItems.isEmpty) return _emptyCard('No songs in playlist yet');
        return Column(
          children: validItems.map((item) => _TrackRow(item: item)).toList(),
        );
      },
    );
  }

  Widget _buildVotesSection(
      AsyncValue<List<Map<String, dynamic>>> votesAsync, String? userId) {
    return votesAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
            child: CircularProgressIndicator(color: Color(0xFF1DB954))),
      ),
      error: (e, _) => _emptyCard('Could not load votes'),
      data: (votes) {
        if (votes.isEmpty) return _emptyCard('No pending votes yet');
        return Column(
          children: votes
              .map((vote) => _PendingVoteRow(vote: vote, userId: userId))
              .toList(),
        );
      },
    );
  }
}

// ── Header ─────────────────────────────────────────────────────────────────────

class _PlaylistHeader extends StatelessWidget {
  final String name;
  final int memberCount;
  final String? coverUrl;

  const _PlaylistHeader({required this.name, required this.memberCount, this.coverUrl});

  @override
  Widget build(BuildContext context) {
    final memberLabel =
        '$memberCount ${memberCount == 1 ? 'member' : 'members'}';

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: coverUrl != null
              ? Image.network(
                  coverUrl!,
                  width: 120,
                  height: 120,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _coverPlaceholder(),
                )
              : _coverPlaceholder(),
        ),
        const SizedBox(height: 16),
        Text(
          name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),
        Text(
          memberLabel,
          style: const TextStyle(color: Colors.grey, fontSize: 14),
        ),
      ],
    );
  }

  Widget _coverPlaceholder() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: const Color(0xFF1DB954).withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Icon(
        Icons.library_music,
        color: Color(0xFF1DB954),
        size: 52,
      ),
    );
  }
}

// ── Members row ────────────────────────────────────────────────────────────────

class _MembersRow extends StatelessWidget {
  final List<String> members;
  static const _maxVisible = 5;

  const _MembersRow({required this.members});

  @override
  Widget build(BuildContext context) {
    final visible = members.take(_maxVisible).toList();
    final overflow = members.length - _maxVisible;

    return Row(
      children: [
        ...visible.map((id) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _MemberAvatar(userId: id),
            )),
        if (overflow > 0)
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.grey[800],
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '+$overflow',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _MemberAvatar extends StatelessWidget {
  final String userId;

  const _MemberAvatar({required this.userId});

  @override
  Widget build(BuildContext context) {
    final initial = userId.isNotEmpty ? userId[0].toUpperCase() : '?';

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFF1DB954).withOpacity(0.2),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            color: Color(0xFF1DB954),
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

// ── Invite button ──────────────────────────────────────────────────────────────

class _InviteButton extends StatelessWidget {
  final String inviteCode;

  const _InviteButton({required this.inviteCode});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF1DB954),
          side: const BorderSide(color: Color(0xFF1DB954)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        icon: const Icon(Icons.person_add_outlined),
        label: const Text(
          'Invite Member',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        onPressed: inviteCode.isEmpty
            ? null
            : () async {
                final box =
                    context.findRenderObject() as RenderBox?;
                await Share.share(
                  'Join my Rateify group: rateify://join/$inviteCode',
                  sharePositionOrigin: box != null
                      ? box.localToGlobal(Offset.zero) & box.size
                      : Rect.largest,
                );
              },
      ),
    );
  }
}

// ── Propose song button ────────────────────────────────────────────────────────

class _ProposeSongButton extends StatelessWidget {
  final VoidCallback onTap;

  const _ProposeSongButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1DB954),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: 0,
        ),
        icon: const Icon(Icons.add),
        label: const Text(
          'Propose a Song',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        onPressed: onTap,
      ),
    );
  }
}

// ── Track row ─────────────────────────────────────────────────────────────────

class _TrackRow extends StatelessWidget {
  final Map<String, dynamic> item;

  const _TrackRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final track = item['track'] as Map<String, dynamic>;
    final addedBy = item['added_by'] as Map<String, dynamic>?;
    final addedById = addedBy?['id'] as String?;

    final name = track['name'] as String? ?? 'Unknown';
    final artists = track['artists'];
    final firstArtist =
        (artists is List && artists.isNotEmpty) ? artists.first : null;
    final artistName = (firstArtist is Map)
        ? firstArtist['name'] as String? ?? 'Unknown'
        : 'Unknown';

    final album = track['album'];
    final albumImages = (album is Map) ? album['images'] : null;
    final firstImage = (albumImages is List && albumImages.isNotEmpty)
        ? albumImages.first
        : null;
    final imageUrl =
        (firstImage is Map) ? firstImage['url'] as String? : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: imageUrl != null
                ? Image.network(
                    imageUrl,
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _placeholder(),
                  )
                : _placeholder(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  artistName,
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (addedById != null && addedById.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Added by: $addedById',
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: const Color(0xFF212121),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Icon(Icons.music_note, color: Colors.grey, size: 24),
    );
  }
}

// ── Pending vote row ───────────────────────────────────────────────────────────

class _PendingVoteRow extends StatelessWidget {
  final Map<String, dynamic> vote;
  final String? userId;

  const _PendingVoteRow({required this.vote, this.userId});

  @override
  Widget build(BuildContext context) {
    final songName = vote['songName'] as String? ?? 'Unknown';
    final artistName = vote['artistName'] as String? ?? '';
    final albumArt = vote['albumArt'] as String?;
    final ratings = vote['ratings'];
    final voteCount = (ratings is Map) ? ratings.length : 0;
    final status = vote['status'] as String? ?? 'pending';
    final voteId = vote['id'] as String? ?? '';
    final proposedBy = vote['proposedBy'] as String?;
    final canWithdraw =
        status == 'pending' && userId != null && proposedBy == userId;

    final statusColor = switch (status) {
      'accepted' => const Color(0xFF1DB954),
      'rejected' => Colors.red,
      _ => Colors.amber,
    };
    final statusLabel = switch (status) {
      'accepted' => '✓ Accepted',
      'rejected' => '✗ Rejected',
      _ => '⏳ Pending',
    };

    final card = Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
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
                      errorBuilder: (_, __, ___) => _artPlaceholder(),
                    )
                  : _artPlaceholder(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    songName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (artistName.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      artistName,
                      style: const TextStyle(
                          color: Colors.grey, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$voteCount ${voteCount == 1 ? 'vote' : 'votes'}',
                  style: const TextStyle(
                      color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (!canWithdraw) return card;

    return Dismissible(
      key: ValueKey(voteId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.undo, color: Colors.white, size: 28),
      ),
      confirmDismiss: (_) async {
        try {
          await FirestoreService().deletePendingVote(voteId);
          return true;
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Could not withdraw: $e')),
            );
          }
          return false;
        }
      },
      child: card,
    );
  }

  Widget _artPlaceholder() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFF212121),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Icon(Icons.music_note, color: Colors.grey, size: 22),
    );
  }
}

// ── Leave group button ─────────────────────────────────────────────────────────

class _LeaveGroupButton extends StatelessWidget {
  final String groupId;
  final String userId;

  const _LeaveGroupButton({
    required this.groupId,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red,
          side: const BorderSide(color: Colors.red),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        icon: const Icon(Icons.exit_to_app),
        label: const Text(
          'Leave Group',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        onPressed: () => _confirmLeave(context),
      ),
    );
  }

  void _confirmLeave(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Leave Group',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to leave this group?',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await FirestoreService().leaveGroup(groupId, userId);
                if (!context.mounted) return;
                Navigator.pop(context);
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            child: const Text('Leave',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
