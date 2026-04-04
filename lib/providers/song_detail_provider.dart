import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/firestore_service.dart';
import 'spotify_provider.dart';

class SongDetailNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> submitRating(
      String songId, String userId, int rating) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final userAsync = ref.read(userProvider);
      if (userAsync.isLoading) {
        throw Exception('User data is still loading, please try again');
      }
      final user = userAsync.value;
      if (user == null) {
        throw Exception('Failed to load user data, cannot submit rating');
      }
      final realUserId = user['id'] as String?;
      if (realUserId == null || realUserId.isEmpty) {
        throw Exception('Spotify user ID is missing');
      }
      final existingRating =
          await ref.read(existingRatingProvider(songId).future);
      if (existingRating != null) {
        await FirestoreService().updateRating(songId, realUserId, rating);
      } else {
        await FirestoreService().submitRating(songId, realUserId, rating);
      }
      ref.invalidate(existingRatingProvider(songId));
    });
  }
}

final songDetailProvider = AsyncNotifierProvider<SongDetailNotifier, void>(
  SongDetailNotifier.new,
);

final existingRatingProvider =
    FutureProvider.autoDispose.family<int?, String>((ref, songId) async {
  final userAsync = ref.watch(userProvider);
  final userId = userAsync.value?['id'] as String?;
  if (userId == null) return null;
  return FirestoreService().getUserRatingForSong(songId, userId);
});
