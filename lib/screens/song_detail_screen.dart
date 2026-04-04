import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/song_detail_provider.dart';
import '../providers/spotify_provider.dart';

final selectedRatingProvider = StateProvider.autoDispose<int>((ref) => 0);

class SongDetailScreen extends ConsumerWidget {
  final Map<String, dynamic> track;

  const SongDetailScreen({super.key, required this.track});

  Future<void> _openInSpotify(String trackId) async {
    final deeplink = Uri.parse('spotify:track:$trackId');
    if (await canLaunchUrl(deeplink)) {
      await launchUrl(deeplink);
    } else {
      await launchUrl(
        Uri.parse('https://open.spotify.com/track/$trackId'),
        mode: LaunchMode.externalApplication,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final submitState = ref.watch(songDetailProvider);
    final selectedRating = ref.watch(selectedRatingProvider);

    final trackName = track['name'] as String? ?? '';
    final artistName =
        (track['artists'] as List?)?.firstOrNull?['name'] as String? ?? '';
    final imageUrl =
        ((track['album']?['images'] as List?)?.firstOrNull
            as Map?)?['url'] as String?;
    final String? songId = track['id'] as String?;

    final existingRatingAsync =
        songId != null ? ref.watch(existingRatingProvider(songId)) : null;

    // Pre-fill stars once existing rating loads
    ref.listen<AsyncValue<int?>>(
      existingRatingProvider(songId ?? ''),
      (_, state) {
        final rating = state.value;
        if (rating != null && rating > 0) {
          ref.read(selectedRatingProvider.notifier).state = rating;
        }
      },
    );

    ref.listen<AsyncValue<void>>(songDetailProvider, (_, state) {
      if (state is AsyncData) {
        ref.invalidate(userRatingsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rating submitted!')),
        );
      } else if (state is AsyncError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${state.error}')),
        );
      }
    });

    final existingRating = existingRatingAsync?.value;
    final isAlreadyRated = existingRating != null && existingRating > 0;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Song Detail'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Album art
            if (imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  imageUrl,
                  width: 220,
                  height: 220,
                  fit: BoxFit.cover,
                ),
              )
            else
              Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.music_note,
                    color: Colors.grey, size: 64),
              ),
            const SizedBox(height: 20),

            // Track name
            Text(
              trackName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // Artist name
            Text(
              artistName,
              style: const TextStyle(color: Colors.grey, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Open in Spotify button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1DB954),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                onPressed:
                    songId != null ? () => _openInSpotify(songId) : null,
                icon: const Icon(Icons.play_circle_fill,
                    color: Colors.white, size: 22),
                label: const Text(
                  'Play in Spotify',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Existing rating label
            if (existingRatingAsync == null || existingRatingAsync.isLoading)
              const SizedBox(
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Color(0xFF1DB954)),
              )
            else if (isAlreadyRated)
              Text(
                'You rated this song $existingRating★',
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              )
            else
              const SizedBox.shrink(),

            const SizedBox(height: 12),

            // Star rating row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final starValue = index + 1;
                return IconButton(
                  onPressed: () => ref
                      .read(selectedRatingProvider.notifier)
                      .state = starValue,
                  icon: Icon(
                    starValue <= selectedRating
                        ? Icons.star
                        : Icons.star_border,
                    color: starValue <= selectedRating
                        ? Colors.white
                        : Colors.grey,
                    size: 36,
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),

            // Submit button / loading indicator
            submitState.isLoading
                ? const CircularProgressIndicator(color: Color(0xFF1DB954))
                : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1DB954),
                        disabledBackgroundColor: Colors.grey[800],
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      onPressed: selectedRating == 0 || songId == null
                          ? null
                          : () => ref
                              .read(songDetailProvider.notifier)
                              .submitRating(songId, '', selectedRating),
                      child: Text(
                        selectedRating == 0
                            ? 'Select a rating'
                            : isAlreadyRated
                                ? 'Update Rating'
                                : 'Submit Rating',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 16),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
