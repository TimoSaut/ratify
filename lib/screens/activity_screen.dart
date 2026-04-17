import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'settings_screen.dart';
import '../providers/spotify_provider.dart';
import '../providers/auth_provider.dart';
import '../services/spotify_service.dart';
import '../services/firestore_service.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final _rateifyGroupsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final userId = ref.watch(userProvider).value?['id'] as String?;
  if (userId == null) return [];
  return FirestoreService().getGroupsForUser(userId);
});

final _spotifyPlaylistsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final authService = ref.read(authServiceProvider);
  return SpotifyService(authService: authService).getUserPlaylists();
});

class _Section2Notifier extends Notifier<bool> {
  @override
  bool build() => false;
  void toggle() => state = !state;
}

final _section2ExpandedProvider =
    NotifierProvider<_Section2Notifier, bool>(_Section2Notifier.new);

// ── Helpers ───────────────────────────────────────────────────────────────────

Future<String> _createGroup(
    String name, String spotifyPlaylistId, String userId) async {
  return FirestoreService().createGroup(name, spotifyPlaylistId, userId);
}

Future<String> _getInviteCode(String groupId) async {
  final doc = await FirebaseFirestore.instance
      .collection('groups')
      .doc(groupId)
      .get();
  return doc.data()?['inviteCode'] as String? ?? '';
}

Future<void> _shareInviteLink(BuildContext context, String inviteCode) async {
  final box = context.findRenderObject() as RenderBox?;
  await Share.share(
    'Join my Rateify group: rateify://join/$inviteCode',
    sharePositionOrigin: box!.localToGlobal(Offset.zero) & box.size,
  );
}

// ── Screen ────────────────────────────────────────────────────────────────────

class ActivityScreen extends ConsumerWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userValue = ref.watch(userProvider).value;
    final images = userValue?['images'];
    final profileImageUrl = (images is List && images.isNotEmpty)
        ? images.first['url'] as String?
        : null;
    final userId = userValue?['id'] as String?;

    final groupsAsync = ref.watch(_rateifyGroupsProvider);
    final spotifyAsync = ref.watch(_spotifyPlaylistsProvider);
    final isExpanded = ref.watch(_section2ExpandedProvider);

    final isLoading = groupsAsync.isLoading || spotifyAsync.isLoading;

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
          'Playlists',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1DB954)),
            )
          : _buildBody(context, ref, userId, groupsAsync.value ?? [],
              spotifyAsync.value ?? [], isExpanded),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    String? userId,
    List<Map<String, dynamic>> groups,
    List<Map<String, dynamic>> spotifyPlaylists,
    bool isExpanded,
  ) {
    // IDs of Spotify playlists already linked to a Rateify group
    final linkedIds = groups
        .map((g) => g['spotifyPlaylistId'] as String?)
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();

    // Spotify playlists not yet in Rateify
    final unlinked = spotifyPlaylists
        .where((p) {
          final id = p['id'] as String?;
          return id != null && !linkedIds.contains(id);
        })
        .toList();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // ── Section 1: Your Rateify Playlists ───────────────────────────
        if (groups.isNotEmpty) ...[
          const Text(
            'Your Rateify Playlists',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...groups.map((group) => _GroupCard(
                group: group,
                onTap: () {
                  final name = group['name'] as String? ?? 'Untitled';
                  final id = group['id'] as String? ?? '';
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GroupDetailScreen(
                        groupId: id,
                        playlistName: name,
                      ),
                    ),
                  );
                },
              )),
          const SizedBox(height: 16),
        ],

        // ── Section 2: Add More Playlists ────────────────────────────────
        if (unlinked.isNotEmpty) ...[
          GestureDetector(
            onTap: () =>
                ref.read(_section2ExpandedProvider.notifier).toggle(),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Add More Playlists',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: Colors.grey,
                ),
              ],
            ),
          ),
          if (isExpanded) ...[
            const SizedBox(height: 12),
            ...unlinked.map((playlist) => _SpotifyPlaylistCard(
                  playlist: playlist,
                  onAdd: userId == null
                      ? null
                      : () => _addPlaylist(context, ref, playlist, userId),
                )),
          ],
          const SizedBox(height: 16),
        ],

        // ── Bottom button ─────────────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1DB954),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              elevation: 0,
            ),
            icon: const Icon(Icons.add),
            label: const Text(
              'Create New Playlist',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            onPressed: userId == null
                ? null
                : () => _showCreateDialog(context, ref, userId),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Future<void> _addPlaylist(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> playlist,
    String userId,
  ) async {
    final name = playlist['name'] as String? ?? 'Untitled';
    final spotifyId = playlist['id'] as String? ?? '';
    try {
      final groupId = await _createGroup(name, spotifyId, userId);
      final inviteCode = await _getInviteCode(groupId);
      ref.invalidate(_rateifyGroupsProvider);
      if (!context.mounted) return;
      await _shareInviteLink(context, inviteCode);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _showCreateDialog(
      BuildContext context, WidgetRef ref, String userId) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Create New Playlist',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Playlist Name',
            hintStyle: TextStyle(color: Colors.grey),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.grey),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF1DB954)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(dialogContext);
              try {
                final groupId = await _createGroup(name, '', userId);
                final inviteCode = await _getInviteCode(groupId);
                ref.invalidate(_rateifyGroupsProvider);
                if (!context.mounted) return;
                await _shareInviteLink(context, inviteCode);
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Create',
                style: TextStyle(color: Color(0xFF1DB954))),
          ),
        ],
      ),
    );
  }
}

// ── Private card widgets ──────────────────────────────────────────────────────

class _GroupCard extends StatelessWidget {
  final Map<String, dynamic> group;
  final VoidCallback onTap;

  const _GroupCard({required this.group, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = group['name'] as String? ?? 'Untitled';
    final memberCount = (group['members'] as List?)?.length ?? 0;
    final memberLabel =
        '$memberCount ${memberCount == 1 ? 'member' : 'members'}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              // Cover art placeholder with green checkmark badge
              Stack(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1DB954).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.library_music,
                        color: Color(0xFF1DB954), size: 28),
                  ),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_circle,
                          color: Color(0xFF1DB954), size: 20),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      memberLabel,
                      style: const TextStyle(
                          color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right,
                  color: Colors.grey, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpotifyPlaylistCard extends StatelessWidget {
  final Map<String, dynamic> playlist;
  final VoidCallback? onAdd;

  const _SpotifyPlaylistCard({required this.playlist, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final name = playlist['name'] as String? ?? 'Untitled';
    final coverImages = playlist['images'] as List?;
    final coverUrl = (coverImages != null && coverImages.isNotEmpty)
        ? coverImages.first['url'] as String?
        : null;
    final owner = playlist['owner'] as Map<String, dynamic>?;
    final ownerName = owner?['display_name'] as String? ?? 'Unknown';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            // Cover art greyed out
            Opacity(
              opacity: 0.4,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: coverUrl != null
                    ? Image.network(
                        coverUrl,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _placeholder(),
                      )
                    : _placeholder(),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ownerName,
                    style: const TextStyle(
                        color: Colors.grey, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline,
                  color: Color(0xFF1DB954)),
              onPressed: onAdd,
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFF1DB954).withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.library_music,
          color: Color(0xFF1DB954), size: 28),
    );
  }
}

// ── GroupDetailScreen (stub) ──────────────────────────────────────────────────

class GroupDetailScreen extends StatelessWidget {
  final String groupId;
  final String playlistName;

  const GroupDetailScreen({
    super.key,
    required this.groupId,
    required this.playlistName,
  });

  @override
  Widget build(BuildContext context) {
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
      ),
      body: Center(
        child: Text(
          'Group ID: $groupId',
          style: const TextStyle(color: Colors.grey),
        ),
      ),
    );
  }
}
