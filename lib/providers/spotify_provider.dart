import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/spotify_service.dart';
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

class PlaylistTracksNotifier
    extends FamilyAsyncNotifier<List<Map<String, dynamic>>, String> {
  @override
  Future<List<Map<String, dynamic>>> build(String playlistId) async {
    final authService = ref.read(authServiceProvider);
    return SpotifyService(authService: authService).getPlaylistTracks(playlistId);
  }
}

final playlistTracksProvider = AsyncNotifierProvider.family<
    PlaylistTracksNotifier, List<Map<String, dynamic>>, String>(
  PlaylistTracksNotifier.new,
);
