import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/song_detail_provider.dart';
import '../providers/spotify_provider.dart';
import '../services/firestore_service.dart';

final selectedRatingProvider = StateProvider.autoDispose<int>((ref) => 0);

class SongDetailScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> track;
  final String? groupId;
  final String? pendingVoteId;

  const SongDetailScreen({
    super.key,
    required this.track,
    this.groupId,
    this.pendingVoteId,
  });

  @override
  ConsumerState<SongDetailScreen> createState() => _SongDetailScreenState();
}

class _SongDetailScreenState extends ConsumerState<SongDetailScreen> {
  // Set to true when "Rate & Propose" is tapped so the rating listener
  // knows to follow up with the propose step instead of showing the
  // normal "Rating submitted!" snackbar.
  bool _proposePending = false;
  bool _votePending = false;

  @override
  void initState() {
    super.initState();
    // Debug: print mode values so we can verify what the screen receives.
    debugPrint(
      '[SongDetailScreen] pendingVoteId=${widget.pendingVoteId} '
      'groupId=${widget.groupId}',
    );
  }

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

  Future<void> _submitVote(BuildContext context, int rating) async {
    final userId = ref.read(userProvider).value?['id'] as String?;
    if (userId == null || widget.pendingVoteId == null || rating == 0) return;
    final songId = widget.track['id'] as String? ?? '';
    setState(() => _votePending = true);
    try {
      // Save to the group's pending vote ratings map and resolve if all voted.
      await FirestoreService()
          .submitVoteOnPendingVote(widget.pendingVoteId!, userId, rating);
      // Also persist to the user's personal library ratings collection.
      if (songId.isNotEmpty) {
        await FirestoreService().updateRating(songId, userId, rating);
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vote submitted!'),
          backgroundColor: Color(0xFF1DB954),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _votePending = false);
    }
  }

  Future<void> _doPropose(BuildContext context) async {
    setState(() => _proposePending = false);
    ref.invalidate(userRatingsProvider);

    final userId = ref.read(userProvider).value?['id'] as String?;
    final groupId = widget.groupId;
    // Read rating synchronously before any awaits
    final rating = ref.read(selectedRatingProvider);
    if (userId == null || groupId == null) return;

    final songId = widget.track['id'] as String? ?? '';
    final songName = widget.track['name'] as String? ?? '';
    final artistName =
        (widget.track['artists'] as List?)?.firstOrNull?['name'] as String? ??
            '';
    final albumArt =
        ((widget.track['album']?['images'] as List?)?.firstOrNull
                    as Map?)?['url'] as String? ??
            '';

    try {
      final pendingVoteId = await FirestoreService().proposeSong(
        groupId: groupId,
        songId: songId,
        songName: songName,
        artistName: artistName,
        albumArt: albumArt,
        proposedBy: userId,
        proposerRating: rating,
      );
      // Check whether all members have now voted (resolves immediately
      // for solo groups, stays pending otherwise)
      await FirestoreService().checkAndResolvePendingVote(pendingVoteId);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Song proposed to group!'),
          backgroundColor: Color(0xFF1DB954),
        ),
      );
      final nav = Navigator.of(context);
      nav.pop(); // back to search screen
      nav.pop(); // back to group detail
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final submitState = ref.watch(songDetailProvider);
    final selectedRating = ref.watch(selectedRatingProvider);
    final isProposeMode = widget.groupId != null;
    // Vote mode: opened from a pending vote card, not from the propose flow.
    // When groupId is also set it means the user is still in the propose flow.
    final isVoteMode = widget.pendingVoteId != null && widget.groupId == null;

    final trackName = widget.track['name'] as String? ?? '';
    final artistName =
        (widget.track['artists'] as List?)?.firstOrNull?['name'] as String? ??
            '';
    final imageUrl =
        ((widget.track['album']?['images'] as List?)?.firstOrNull
            as Map?)?['url'] as String?;
    final String? songId = widget.track['id'] as String?;

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
      if (state is AsyncData && _proposePending) {
        // Propose mode: rating saved — now propose to the group
        _doPropose(context);
      } else if (state is AsyncData && !_proposePending) {
        // Normal mode: just confirm the rating
        ref.invalidate(userRatingsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rating submitted!')),
        );
      } else if (state is AsyncError) {
        if (_proposePending) setState(() => _proposePending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${state.error}')),
        );
      }
    });

    final existingRating = existingRatingAsync?.value;
    final isAlreadyRated = existingRating != null && existingRating > 0;

    // In vote mode, fall back to the library rating if the user hasn't
    // tapped stars yet — this covers the case where existingRatingProvider
    // was already cached and the ref.listen never fired.
    final effectiveRating = (isVoteMode && selectedRating == 0 && isAlreadyRated)
        ? existingRating
        : selectedRating;

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

            // Star rating row — uses effectiveRating so pre-filled stars
            // are visible immediately even before the listener fires.
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final starValue = index + 1;
                return IconButton(
                  onPressed: () => ref
                      .read(selectedRatingProvider.notifier)
                      .state = starValue,
                  icon: Icon(
                    starValue <= effectiveRating
                        ? Icons.star
                        : Icons.star_border,
                    color: starValue <= effectiveRating
                        ? Colors.white
                        : Colors.grey,
                    size: 36,
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),

            // Submit / Rate & Propose / Submit Vote button
            submitState.isLoading || _proposePending || _votePending
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
                      onPressed: (isVoteMode ? effectiveRating == 0 : selectedRating == 0) ||
                              songId == null
                          ? null
                          : isVoteMode
                              ? () => _submitVote(context, effectiveRating)
                              : isProposeMode
                                  ? () {
                                      setState(() => _proposePending = true);
                                      ref
                                          .read(songDetailProvider.notifier)
                                          .submitRating(
                                              songId, '', selectedRating);
                                    }
                                  : () => ref
                                      .read(songDetailProvider.notifier)
                                      .submitRating(songId, '', selectedRating),
                      child: Text(
                        isVoteMode
                            ? (effectiveRating == 0
                                ? 'Select a rating to vote'
                                : 'Submit Vote')
                            : selectedRating == 0
                                ? (isProposeMode
                                    ? 'Select a rating to propose'
                                    : 'Select a rating')
                                : (isProposeMode
                                    ? 'Rate & Propose'
                                    : (isAlreadyRated
                                        ? 'Update Rating'
                                        : 'Submit Rating')),
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
