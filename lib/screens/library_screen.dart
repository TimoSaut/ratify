import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'settings_screen.dart';
import 'song_detail_screen.dart';
import '../providers/spotify_provider.dart';

// Tracks which playlist ID is currently being loaded on tap (null = none).
final _loadingPlaylistIdProvider = StateProvider<String?>((ref) => null);

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlistsAsync = ref.watch(playlistsProvider);
    final loadingId = ref.watch(_loadingPlaylistIdProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        centerTitle: true,
        elevation: 0,
        leading: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            );
          },
          child: const Padding(
            padding: EdgeInsets.all(8.0),
            child: CircleAvatar(
              backgroundColor: Color(0xFF535353),
              child: Icon(Icons.person, color: Colors.white),
            ),
          ),
        ),
        title: const Text(
          "Library",
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: playlistsAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: Color(0xFF1DB954)),
          ),
          error: (e, _) => Center(
            child: Text('Failed to load playlists: $e',
                style: const TextStyle(color: Colors.red)),
          ),
          data: (playlists) => ListView.separated(
            itemCount: playlists.length,
            separatorBuilder: (_, __) =>
                const Divider(color: Color(0xFF333333), height: 1),
            itemBuilder: (context, index) {
              final playlist = playlists[index];
              final playlistId = playlist['id'] as String? ?? '';
              final name = playlist['name'] as String? ?? '';
              final trackCount =
                  (playlist['tracks']?['total'] as int?) ?? 0;
              final isLoading = loadingId == playlistId;

              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.queue_music,
                    color: Color(0xFF1DB954)),
                title: Text(name,
                    style: const TextStyle(color: Colors.white)),
                subtitle: Text('$trackCount tracks',
                    style: const TextStyle(color: Colors.grey)),
                trailing: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF1DB954)),
                      )
                    : const Icon(Icons.chevron_right, color: Colors.grey),
                onTap: isLoading
                    ? null
                    : () async {
                        ref
                            .read(_loadingPlaylistIdProvider.notifier)
                            .state = playlistId;
                        try {
                          final items = await ref.read(
                            playlistTracksProvider(playlistId).future,
                          );
                          final track = items
                              .map((item) =>
                                  item['track'] as Map<String, dynamic>?)
                              .whereType<Map<String, dynamic>>()
                              .firstOrNull;
                          if (track != null && context.mounted) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    SongDetailScreen(track: track),
                              ),
                            );
                          }
                        } finally {
                          ref
                              .read(_loadingPlaylistIdProvider.notifier)
                              .state = null;
                        }
                      },
              );
            },
          ),
        ),
      ),
    );
  }
}
