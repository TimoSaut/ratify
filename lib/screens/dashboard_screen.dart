import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'settings_screen.dart';
import '../providers/library_provider.dart';
import '../providers/spotify_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songs = ref.watch(libraryProvider);
    final ratedCount = songs.length;
    final userAsync = ref.watch(userProvider);
    final playlistsAsync = ref.watch(playlistsProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
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
          "Dashboard",
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Greeting
            userAsync.when(
              loading: () => const SizedBox(
                height: 28,
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Color(0xFF1DB954)),
                  ),
                ),
              ),
              error: (e, _) => Text('Error: $e',
                  style: const TextStyle(color: Colors.red, fontSize: 14)),
              data: (user) => Text(
                'Hey ${user['display_name'] ?? 'there'} 👋',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Stats grid
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF212121),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                "No requests pending",
                style: TextStyle(color: Colors.white, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 20),
            GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _StatCard(label: "Rated Songs", value: ratedCount.toString()),
                const _StatCard(label: "Unrated Songs", value: "82"),
                const _StatCard(label: "Pending Requests", value: "1"),
                playlistsAsync.when(
                  loading: () =>
                      const _StatCard(label: "Total Playlists", value: "…"),
                  error: (_, __) =>
                      const _StatCard(label: "Total Playlists", value: "—"),
                  data: (playlists) => _StatCard(
                    label: "Total Playlists",
                    value: playlists.length.toString(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Playlists list
            const Text(
              'Your Playlists',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
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
                  separatorBuilder: (_, __) => const Divider(
                      color: Color(0xFF333333), height: 1),
                  itemBuilder: (context, index) {
                    final playlist = playlists[index];
                    final name = playlist['name'] as String? ?? '';
                    final trackCount =
                        (playlist['tracks']?['total'] as int?) ?? 0;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(name,
                          style: const TextStyle(color: Colors.white)),
                      subtitle: Text('$trackCount tracks',
                          style: const TextStyle(color: Colors.grey)),
                      leading: const Icon(Icons.queue_music,
                          color: Color(0xFF1DB954)),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;

  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF212121),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
