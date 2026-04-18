import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/spotify_provider.dart';
import '../providers/auth_provider.dart';
import '../services/spotify_service.dart';
import '../services/firestore_service.dart';

class SearchScreen extends ConsumerStatefulWidget {
  final String groupId;

  const SearchScreen({super.key, required this.groupId});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  Timer? _debounce;

  List<Map<String, dynamic>> _results = [];
  bool _isLoading = false;
  bool _hasSearched = false;

  // Tracks whose "add to library" request is in-flight
  final Set<String> _savingIds = {};
  // trackId → true if saved in Spotify library
  final Map<String, bool> _savedStatus = {};

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ── Search ────────────────────────────────────────────────────────────────

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _isLoading = false;
        _hasSearched = false;
      });
      return;
    }
    setState(() => _isLoading = true);
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      final authService = ref.read(authServiceProvider);
      try {
        final service = SpotifyService(authService: authService);
        final results = await service.searchTracks(query.trim());

        // Check which tracks are already in the user's library
        final ids = results
            .map((t) => t['id'] as String?)
            .whereType<String>()
            .toList();
        final savedList = await service.checkSavedTracks(ids);
        final savedStatus = {
          for (var i = 0; i < ids.length; i++) ids[i]: savedList[i],
        };

        if (!mounted) return;
        setState(() {
          _results = results;
          _savedStatus
            ..clear()
            ..addAll(savedStatus);
          _isLoading = false;
          _hasSearched = true;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _hasSearched = true;
        });
      }
    });
  }

  // ── Add to library ────────────────────────────────────────────────────────

  Future<void> _addToLibrary(String trackId) async {
    if (_savingIds.contains(trackId) || _savedStatus[trackId] == true) return;
    setState(() => _savingIds.add(trackId));

    final authService = ref.read(authServiceProvider);
    try {
      await SpotifyService(authService: authService)
          .addTrackToLibrary(trackId);
      if (!mounted) return;
      setState(() {
        _savingIds.remove(trackId);
        _savedStatus[trackId] = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _savingIds.remove(trackId));
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  // ── Propose ───────────────────────────────────────────────────────────────

  Future<void> _proposeSong(Map<String, dynamic> track) async {
    final userId = ref.read(userProvider).value?['id'] as String?;
    if (userId == null) return;

    final songId = track['id'] as String? ?? '';
    final songName = track['name'] as String? ?? '';
    final artistName =
        (track['artists'] as List?)?.firstOrNull?['name'] as String? ?? '';
    final albumArt =
        ((track['album']?['images'] as List?)?.firstOrNull as Map?)?['url']
                as String? ??
            '';

    try {
      await FirestoreService().proposeSong(
        groupId: widget.groupId,
        songId: songId,
        songName: songName,
        artistName: artistName,
        albumArt: albumArt,
        proposedBy: userId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Song proposed!'),
          backgroundColor: Color(0xFF1DB954),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: TextField(
          controller: _controller,
          focusNode: _focusNode,
          onChanged: _onSearchChanged,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          cursorColor: const Color(0xFF1DB954),
          decoration: const InputDecoration(
            hintText: 'Search for a song…',
            hintStyle: TextStyle(color: Colors.grey),
            border: InputBorder.none,
          ),
          textInputAction: TextInputAction.search,
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF1DB954)),
      );
    }

    if (!_hasSearched) {
      return const Center(
        child: Text(
          'Search for a song to propose',
          style: TextStyle(color: Colors.grey, fontSize: 15),
        ),
      );
    }

    if (_results.isEmpty) {
      return const Center(
        child: Text(
          'No results found',
          style: TextStyle(color: Colors.grey, fontSize: 15),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _results.length,
      separatorBuilder: (_, __) =>
          const Divider(color: Color(0xFF2A2A2A), height: 1),
      itemBuilder: (context, index) {
        final track = _results[index];
        final trackId = track['id'] as String? ?? '';
        final name = track['name'] as String? ?? '';
        final artistName =
            (track['artists'] as List?)?.firstOrNull?['name'] as String? ?? '';
        final imageUrl =
            ((track['album']?['images'] as List?)?.firstOrNull as Map?)?['url']
                as String?;

        final isSaving = _savingIds.contains(trackId);
        final isSaved = _savedStatus[trackId] == true;

        return ListTile(
          contentPadding:
              const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: imageUrl != null
                ? Image.network(
                    imageUrl,
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _placeholder(),
                  )
                : _placeholder(),
          ),
          title: Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            artistName,
            style: const TextStyle(color: Colors.grey, fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Add to library button
              SizedBox(
                width: 36,
                height: 36,
                child: isSaving
                    ? const Padding(
                        padding: EdgeInsets.all(8),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.grey,
                        ),
                      )
                    : IconButton(
                        padding: EdgeInsets.zero,
                        icon: Icon(
                          isSaved ? Icons.check_circle : Icons.add_circle_outline,
                          color: isSaved
                              ? const Color(0xFF1DB954)
                              : Colors.grey,
                          size: 22,
                        ),
                        onPressed:
                            isSaved ? null : () => _addToLibrary(trackId),
                      ),
              ),
              const SizedBox(width: 4),
              // Propose button
              TextButton(
                onPressed: () => _proposeSong(track),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF1DB954),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
                child: const Text('Propose'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _placeholder() {
    return Container(
      width: 50,
      height: 50,
      color: const Color(0xFF212121),
      child: const Icon(Icons.music_note, color: Colors.grey, size: 24),
    );
  }
}
