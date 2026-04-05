import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'settings_screen.dart';
import '../providers/spotify_provider.dart';

class ActivityScreen extends ConsumerWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileImageUrl =
        ref.watch(userProvider).value?['images']?.first?['url'] as String?;

    final List<Map<String, String>> activities = [
      {
        "user": "Danny",
        "song": "12 to 12",
        "artist": "Sombr",
        "playlist": "Car Playlist",
      },
      {
        "user": "Lucas F.",
        "song": "Life is Good (feat. Drake)",
        "artist": "Future",
        "playlist": "Party 🪩",
      },
      {
        "user": "Danny",
        "song": "Herbst",
        "artist": "Souly",
        "playlist": "Night Drive 🎧",
      },
      {
        "user": "Max S.",
        "song": "FEIN!",
        "artist": "Travis Scott",
        "playlist": "Party 🪩",
      },
      {
        "user": "Danny",
        "song": "12 to 12",
        "artist": "Sombr",
        "playlist": "Car Playlist",
      },
    ];

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
          "Playlists",
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
          children: [
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
            Expanded(
              child: ListView.separated(
                itemCount: activities.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final activity = activities[index];
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF212121),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: const Color(0xFF535353),
                          child: Text(
                            activity["user"]![0],
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '${activity["user"]} added "${activity["song"]}" from ${activity["artist"]} in "${activity["playlist"]}"',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
