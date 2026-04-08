import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/spotify_provider.dart';
import '../services/firestore_service.dart';
import '../services/spotify_service.dart';
import 'group_detail_screen.dart';
import 'settings_screen.dart';

final collaborativePlaylistsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final authService = ref.read(authServiceProvider);
  final all = await SpotifyService(authService: authService).getUserPlaylists();
  return all
      .where((p) => p['collaborative'] == true)
      .toList();
});

class ActivityScreen extends ConsumerWidget {
  const ActivityScreen({super.key});

  Future<void> _onPlaylistTap(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> playlist,
  ) async {
    final userId = ref.read(userProvider).value?['id'] as String?;
    if (userId == null) return;

    final playlistId = playlist['id'] as String;
    final playlistName = playlist['name'] as String? ?? '';

    // Check if a Rateify group already exists for this Spotify playlist.
    final query = await FirebaseFirestore.instance
        .collection('groups')
        .where('spotifyPlaylistId', isEqualTo: playlistId)
        .limit(1)
        .get();

    String groupId;
    if (query.docs.isNotEmpty) {
      groupId = query.docs.first.id;
    } else {
      groupId = await FirestoreService()
          .createGroup(playlistName, playlistId, userId);
    }

    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GroupDetailScreen(
            groupId: groupId,
            playlistName: playlistName,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileImageUrl =
        ref.watch(userProvider).value?['images']?.first?['url'] as String?;
    final playlistsAsync = ref.watch(collaborativePlaylistsProvider);

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
      body: playlistsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFF1DB954)),
        ),
        error: (e, _) => Center(
          child: Text('Error: $e', style: const TextStyle(color: Colors.grey)),
        ),
        data: (playlists) {
          if (playlists.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.library_music,
                      color: Colors.grey, size: 52),
                  const SizedBox(height: 16),
                  const Text(
                    'No collaborative playlists found',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Create a shared playlist in Spotify first',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1DB954),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    onPressed: () {
                      // Deeplink to Spotify app.
                      // url_launcher would be used here; for now a no-op.
                    },
                    child: const Text(
                      'Open Spotify',
                      style: TextStyle(color: Colors.white, fontSize: 15),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: playlists.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final playlist = playlists[index];
              final name = playlist['name'] as String? ?? '';
              final ownerName =
                  (playlist['owner'] as Map<String, dynamic>?)?['display_name']
                      as String? ??
                  '';
              final images = playlist['images'] as List?;
              final coverUrl = images != null && images.isNotEmpty
                  ? images[0]['url'] as String?
                  : null;

              return GestureDetector(
                onTap: () => _onPlaylistTap(context, ref, playlist),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: coverUrl != null
                            ? Image.network(
                                coverUrl,
                                width: 56,
                                height: 56,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                width: 56,
                                height: 56,
                                color: const Color(0xFF282828),
                                child: const Icon(Icons.music_note,
                                    color: Colors.grey, size: 28),
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
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (ownerName.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                ownerName,
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right,
                          color: Colors.grey, size: 22),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
