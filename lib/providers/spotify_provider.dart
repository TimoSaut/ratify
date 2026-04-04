import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/spotify_service.dart';
import '../services/firestore_service.dart';
import 'auth_provider.dart';

class UserNotifier extends AsyncNotifier<Map<String, dynamic>> {
  @override
  Future<Map<String, dynamic>> build() async {
    final authService = ref.read(authServiceProvider);
    return SpotifyService(authService: authService).getCurrentUser();
  }
}

final userProvider = AsyncNotifierProvider<UserNotifier, Map<String, dynamic>>(
  UserNotifier.new,
);

class PlaylistsNotifier extends AsyncNotifier<List<Map<String, dynamic>>> {
  @override
  Future<List<Map<String, dynamic>>> build() async {
    final authService = ref.read(authServiceProvider);
    return SpotifyService(authService: authService).getUserPlaylists();
  }
}

final playlistsProvider =
    AsyncNotifierProvider<PlaylistsNotifier, List<Map<String, dynamic>>>(
  PlaylistsNotifier.new,
);

// ── Paginated state ───────────────────────────────────────────────────────────

class PaginatedLibraryState {
  final List<Map<String, dynamic>> items;
  final bool isLoading;
  final bool hasMore;
  final int offset;

  const PaginatedLibraryState({
    required this.items,
    required this.isLoading,
    required this.hasMore,
    required this.offset,
  });

  PaginatedLibraryState copyWith({
    List<Map<String, dynamic>>? items,
    bool? isLoading,
    bool? hasMore,
    int? offset,
  }) =>
      PaginatedLibraryState(
        items: items ?? this.items,
        isLoading: isLoading ?? this.isLoading,
        hasMore: hasMore ?? this.hasMore,
        offset: offset ?? this.offset,
      );
}

// ── Saved albums ──────────────────────────────────────────────────────────────

class SavedAlbumsNotifier extends Notifier<PaginatedLibraryState> {
  static const _limit = 20;

  @override
  PaginatedLibraryState build() {
    Future.microtask(loadMore);
    return const PaginatedLibraryState(
        items: [], isLoading: false, hasMore: true, offset: 0);
  }

  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore) return;
    print('[SavedAlbumsNotifier] loadMore called — '
        'offset=${state.offset} hasMore=${state.hasMore}');
    state = state.copyWith(isLoading: true);
    try {
      final authService = ref.read(authServiceProvider);
      final page = await SpotifyService(authService: authService)
          .getSavedAlbums(state.offset, _limit);
      final newItems =
          List<Map<String, dynamic>>.from(page['items'] as List);
      print('[SavedAlbumsNotifier] loaded ${newItems.length} albums, '
          'hasMore=${page['next'] != null}');
      state = PaginatedLibraryState(
        items: [...state.items, ...newItems],
        isLoading: false,
        hasMore: page['next'] != null,
        offset: state.offset + newItems.length,
      );
    } catch (e, st) {
      print('[SavedAlbumsNotifier] loadMore error: $e\n$st');
      state = state.copyWith(isLoading: false);
    }
  }
}

final savedAlbumsProvider =
    NotifierProvider<SavedAlbumsNotifier, PaginatedLibraryState>(
  SavedAlbumsNotifier.new,
);

// ── Saved tracks ──────────────────────────────────────────────────────────────

class SavedTracksNotifier extends Notifier<PaginatedLibraryState> {
  static const _limit = 20;

  @override
  PaginatedLibraryState build() {
    Future.microtask(loadMore);
    return const PaginatedLibraryState(
        items: [], isLoading: false, hasMore: true, offset: 0);
  }

  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore) return;
    state = state.copyWith(isLoading: true);
    try {
      final authService = ref.read(authServiceProvider);
      final page = await SpotifyService(authService: authService)
          .getSavedTracks(state.offset, _limit);
      final newItems =
          List<Map<String, dynamic>>.from(page['items'] as List);
      state = PaginatedLibraryState(
        items: [...state.items, ...newItems],
        isLoading: false,
        hasMore: page['next'] != null,
        offset: state.offset + newItems.length,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }
}

final savedTracksProvider =
    NotifierProvider<SavedTracksNotifier, PaginatedLibraryState>(
  SavedTracksNotifier.new,
);

final playlistTracksProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
  (ref, playlistId) async {
    final authService = ref.read(authServiceProvider);
    return SpotifyService(authService: authService).getPlaylistTracks(playlistId);
  },
);

final userRatingsProvider = FutureProvider<Map<String, int>>((ref) async {
  final userAsync = ref.watch(userProvider);
  final userId = userAsync.value?['id'] as String?;
  if (userId == null) return {};
  return FirestoreService().getAllUserRatings(userId);
});
