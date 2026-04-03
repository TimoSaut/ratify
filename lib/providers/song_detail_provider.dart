import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/firestore_service.dart';

class SongDetailNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> submitRating(
      String songId, String userId, int rating) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => FirestoreService().submitRating(songId, userId, rating),
    );
  }
}

final songDetailProvider = AsyncNotifierProvider<SongDetailNotifier, void>(
  SongDetailNotifier.new,
);
