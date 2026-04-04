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
      await FirestoreService().submitRating(songId, realUserId, rating);
    });
  }
}

final songDetailProvider = AsyncNotifierProvider<SongDetailNotifier, void>(
  SongDetailNotifier.new,
);
