import 'dart:convert';
import 'package:http/http.dart' as http;
import '../auth/auth_service.dart';

class SpotifyService {
  final AuthService authService;

  SpotifyService({required this.authService});

  static const _baseUrl = 'https://api.spotify.com/v1';

  Future<Map<String, String>> _authHeaders() async {
    final token = await authService.getValidAccessToken();
    return {'Authorization': 'Bearer $token'};
  }

  Future<Map<String, dynamic>> getCurrentUser() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/me'),
      headers: await _authHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception('getCurrentUser failed (${response.statusCode}): ${response.body}');
    }

    final data = json.decode(response.body) as Map<String, dynamic>;
    return {
      'id': data['id'],
      'display_name': data['display_name'],
      'images': data['images'],
    };
  }

  Future<List<Map<String, dynamic>>> getUserPlaylists() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/me/playlists'),
      headers: await _authHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception('getUserPlaylists failed (${response.statusCode}): ${response.body}');
    }

    final data = json.decode(response.body) as Map<String, dynamic>;
    return List<Map<String, dynamic>>.from(data['items'] as List);
  }

  Future<Map<String, dynamic>> getSavedAlbums(int offset, int limit) async {
    final url = '$_baseUrl/me/albums?limit=$limit&offset=$offset';
    print('[getSavedAlbums] GET $url');

    final response = await http.get(
      Uri.parse(url),
      headers: await _authHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception('getSavedAlbums failed (${response.statusCode}): ${response.body}');
    }

    final data = json.decode(response.body) as Map<String, dynamic>;
    print('[getSavedAlbums] total=${data['total']} '
        'items=${(data['items'] as List).length} '
        'next=${data['next']}');

    final items = <Map<String, dynamic>>[];
    for (final item in data['items'] as List) {
      final album = item['album'];
      if (album == null) {
        print('[getSavedAlbums] skipping item with null album');
        continue;
      }
      items.add(album as Map<String, dynamic>);
    }
    print('[getSavedAlbums] parsed ${items.length} albums');

    return {
      'items': items,
      'next': data['next'],
    };
  }

  Future<Map<String, dynamic>> getSavedTracks(int offset, int limit) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/me/tracks?limit=$limit&offset=$offset'),
      headers: await _authHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception('getSavedTracks failed (${response.statusCode}): ${response.body}');
    }

    final data = json.decode(response.body) as Map<String, dynamic>;
    return {
      'items': (data['items'] as List)
          .map((item) => item['track'] as Map<String, dynamic>)
          .toList(),
      'next': data['next'],
    };
  }

  Future<List<Map<String, dynamic>>> getPlaylistTracks(String playlistId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/playlists/$playlistId/tracks'),
      headers: await _authHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception('getPlaylistTracks failed (${response.statusCode}): ${response.body}');
    }

    final data = json.decode(response.body) as Map<String, dynamic>;
    return List<Map<String, dynamic>>.from(data['items'] as List);
  }

  Future<List<Map<String, dynamic>>> searchTracks(String query) async {
    final uri = Uri.parse('$_baseUrl/search').replace(queryParameters: {
      'q': query,
      'type': 'track',
      'limit': '50',
    });
    final response = await http.get(uri, headers: await _authHeaders());

    if (response.statusCode != 200) {
      throw Exception('searchTracks failed (${response.statusCode}): ${response.body}');
    }

    final data = json.decode(response.body) as Map<String, dynamic>;
    final tracks = data['tracks'] as Map<String, dynamic>;
    return List<Map<String, dynamic>>.from(tracks['items'] as List);
  }

  Future<List<bool>> checkSavedTracks(List<String> trackIds) async {
    if (trackIds.isEmpty) return [];
    final uri = Uri.parse('$_baseUrl/me/tracks/contains')
        .replace(queryParameters: {'ids': trackIds.join(',')});
    final response = await http.get(uri, headers: await _authHeaders());

    if (response.statusCode != 200) {
      throw Exception('checkSavedTracks failed (${response.statusCode}): ${response.body}');
    }

    return List<bool>.from(json.decode(response.body) as List);
  }

  Future<void> addTrackToPlaylist(String playlistId, String trackId) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/playlists/$playlistId/tracks'),
      headers: {
        ...await _authHeaders(),
        'Content-Type': 'application/json',
      },
      body: json.encode({'uris': ['spotify:track:$trackId']}),
    );

    if (response.statusCode != 201) {
      throw Exception(
          'addTrackToPlaylist failed (${response.statusCode}): ${response.body}');
    }
  }

  Future<void> addTrackToLibrary(String trackId) async {
    final response = await http.put(
      Uri.parse('$_baseUrl/me/tracks'),
      headers: {
        ...await _authHeaders(),
        'Content-Type': 'application/json',
      },
      body: json.encode({'ids': [trackId]}),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('addTrackToLibrary failed (${response.statusCode}): ${response.body}');
    }
  }
}
