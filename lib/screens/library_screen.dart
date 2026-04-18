import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'settings_screen.dart';
import 'song_detail_screen.dart';
import '../providers/spotify_provider.dart';
import '../services/firestore_service.dart';

final _libraryToggleProvider = StateProvider.autoDispose<int>((ref) => 0);
// null = All, 0 = Unrated, 1-5 = star count
final _songFilterProvider = StateProvider.autoDispose<int?>((ref) => null);
final _searchQueryProvider = StateProvider.autoDispose<String>((ref) => '');

class LibraryScreen extends ConsumerStatefulWidget {
  final String? groupId;

  const LibraryScreen({super.key, this.groupId});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedTab = ref.watch(_libraryToggleProvider);
    final profileImageUrl =
        ref.watch(userProvider).value?['images']?.first?['url'] as String?;
    final isProposeMode = widget.groupId != null;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        centerTitle: true,
        elevation: 0,
        leading: isProposeMode
            ? null
            : GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
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
        title: Text(
          isProposeMode ? 'Propose a Song' : 'Library',
          style: const TextStyle(
              color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          // Segmented toggle
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF212121),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                children: [
                  _ToggleButton(
                    label: 'Albums',
                    selected: selectedTab == 0,
                    onTap: () =>
                        ref.read(_libraryToggleProvider.notifier).state = 0,
                  ),
                  _ToggleButton(
                    label: 'Songs',
                    selected: selectedTab == 1,
                    onTap: () =>
                        ref.read(_libraryToggleProvider.notifier).state = 1,
                  ),
                ],
              ),
            ),
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _searchController,
              onChanged: (v) =>
                  ref.read(_searchQueryProvider.notifier).state = v.trim(),
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Search…',
                hintStyle:
                    const TextStyle(color: Colors.grey, fontSize: 15),
                prefixIcon:
                    const Icon(Icons.search, color: Colors.grey, size: 20),
                filled: true,
                fillColor: const Color(0xFF1A1A1A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 10),
                isDense: true,
              ),
            ),
          ),

          // Content — each view owns its own provider watch
          Expanded(
            child: selectedTab == 0
                ? _AlbumGrid(groupId: widget.groupId)
                : _SongList(groupId: widget.groupId),
          ),
        ],
      ),
    );
  }
}

// ── Toggle button ─────────────────────────────────────────────────────────────

class _ToggleButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ToggleButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.black : Colors.grey,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Album grid (derived from savedTracksProvider) ─────────────────────────────

class _AlbumGrid extends ConsumerStatefulWidget {
  final String? groupId;

  const _AlbumGrid({this.groupId});

  @override
  ConsumerState<_AlbumGrid> createState() => _AlbumGridState();
}

class _AlbumGridState extends ConsumerState<_AlbumGrid> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
  }

  void _onScroll() {
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 200) {
      ref.read(savedTracksProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tracksState = ref.watch(savedTracksProvider);
    final allTracks = tracksState.items;
    final query = ref.watch(_searchQueryProvider).toLowerCase();

    // Derive unique albums from loaded tracks, preserving first-seen order.
    final seenIds = <String>{};
    final albums = <Map<String, dynamic>>[];
    for (final track in allTracks) {
      final album = track['album'] as Map<String, dynamic>?;
      if (album == null) continue;
      final id = album['id'] as String?;
      if (id == null || !seenIds.add(id)) continue;
      albums.add(album);
    }

    // Filter by search query
    final filtered = query.isEmpty
        ? albums
        : albums.where((a) {
            final name = (a['name'] as String? ?? '').toLowerCase();
            final artist = ((a['artists'] as List?)?.firstOrNull?['name']
                        as String? ??
                    '')
                .toLowerCase();
            return name.contains(query) || artist.contains(query);
          }).toList();

    return Column(
      children: [
        Expanded(
          child: GridView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 16,
              childAspectRatio: 0.75,
            ),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final album = filtered[index];
              final albumId = album['id'] as String? ?? '';
              final name = album['name'] as String? ?? '';
              final artist = (album['artists'] as List?)
                      ?.firstOrNull?['name'] as String? ??
                  '';
              final imageUrl = (album['images'] as List?)
                  ?.firstOrNull?['url'] as String?;

              return GestureDetector(
                onTap: () {
                  final albumTracks = allTracks
                      .where((t) =>
                          (t['album'] as Map?)?['id'] == albumId)
                      .toList();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => _AlbumTracksScreen(
                        album: album,
                        tracks: albumTracks,
                        groupId: widget.groupId,
                      ),
                    ),
                  );
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: imageUrl != null
                            ? Image.network(imageUrl,
                                fit: BoxFit.cover, width: double.infinity)
                            : Container(
                                color: const Color(0xFF212121),
                                child: const Center(
                                  child: Icon(Icons.album,
                                      color: Colors.grey, size: 40),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 13)),
                    Text(artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 12)),
                  ],
                ),
              );
            },
          ),
        ),
        if (tracksState.isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: CircularProgressIndicator(color: Color(0xFF1DB954)),
          ),
      ],
    );
  }
}

// ── Song list (savedTracksProvider, paginated) ────────────────────────────────

class _SongList extends ConsumerStatefulWidget {
  final String? groupId;

  const _SongList({this.groupId});

  @override
  ConsumerState<_SongList> createState() => _SongListState();
}

class _SongListState extends ConsumerState<_SongList> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
  }

  void _onScroll() {
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 200) {
      ref.read(savedTracksProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return Consumer(
          builder: (context, ref, _) {
            final activeFilter = ref.watch(_songFilterProvider);
            final options = <({String label, int? value})>[
              (label: 'All', value: null),
              (label: '1★', value: 1),
              (label: '2★', value: 2),
              (label: '3★', value: 3),
              (label: '4★', value: 4),
              (label: '5★', value: 5),
              (label: 'Unrated', value: 0),
            ];
            return ListView(
              shrinkWrap: true,
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).padding.bottom + 16,
              ),
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(4, 4, 4, 8),
                  child: Text(
                    'Filter by Rating',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                ...options.map((opt) {
                  final selected = activeFilter == opt.value;
                  return ListTile(
                    title: Text(
                      opt.label,
                      style: TextStyle(
                        color: selected
                            ? const Color(0xFF1DB954)
                            : Colors.white,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                    trailing: selected
                        ? const Icon(Icons.check,
                            color: Color(0xFF1DB954), size: 18)
                        : null,
                    onTap: () {
                      ref.read(_songFilterProvider.notifier).state =
                          opt.value;
                      Navigator.pop(context);
                    },
                  );
                }),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _proposeSong(
      BuildContext context, Map<String, dynamic> track) async {
    final groupId = widget.groupId;
    if (groupId == null) return;
    final userId = ref.read(userProvider).value?['id'] as String?;
    if (userId == null) return;

    final songId = track['id'] as String? ?? '';
    final songName = track['name'] as String? ?? '';
    final artistName = (track['artists'] as List?)?.firstOrNull?['name']
            as String? ??
        '';
    final albumArt =
        ((track['album']?['images'] as List?)?.firstOrNull as Map?)?['url']
                as String? ??
            '';

    try {
      await FirestoreService().proposeSong(
        groupId: groupId,
        songId: songId,
        songName: songName,
        artistName: artistName,
        albumArt: albumArt,
        proposedBy: userId,
      );
      if (!context.mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(savedTracksProvider);
    final ratingsAsync = ref.watch(userRatingsProvider);
    final ratings = ratingsAsync.value ?? {};
    final activeFilter = ref.watch(_songFilterProvider);
    final filterActive = activeFilter != null;
    final query = ref.watch(_searchQueryProvider).toLowerCase();
    final isProposeMode = widget.groupId != null;

    var tracks = state.items;

    // Apply rating filter (normal mode only)
    if (!isProposeMode && activeFilter != null) {
      tracks = tracks.where((track) {
        final songId = track['id'] as String?;
        if (songId == null) return false;
        final rating = ratings[songId];
        if (activeFilter == 0) return rating == null;
        return rating == activeFilter;
      }).toList();
    }

    // Apply search filter
    if (query.isNotEmpty) {
      tracks = tracks.where((track) {
        final name = (track['name'] as String? ?? '').toLowerCase();
        final artist = ((track['artists'] as List?)?.firstOrNull?['name']
                    as String? ??
                '')
            .toLowerCase();
        return name.contains(query) || artist.contains(query);
      }).toList();
    }

    return Column(
      children: [
        // Filter bar (normal mode only)
        if (!isProposeMode)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.filter_list,
                    color: filterActive
                        ? const Color(0xFF1DB954)
                        : Colors.grey,
                  ),
                  onPressed: () => _showFilterSheet(context),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView.separated(
            controller: _scrollController,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: tracks.length,
            separatorBuilder: (_, __) =>
                const Divider(color: Color(0xFF2A2A2A), height: 1),
            itemBuilder: (context, index) {
              final track = tracks[index];
              final trackName = track['name'] as String? ?? '';
              final artistName = (track['artists'] as List?)
                      ?.firstOrNull?['name'] as String? ??
                  '';
              final imageUrl = ((track['album']?['images'] as List?)
                      ?.firstOrNull as Map?)?['url'] as String?;
              final songId = track['id'] as String?;
              final rating = songId != null ? ratings[songId] : null;

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                    vertical: 4, horizontal: 0),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: imageUrl != null
                      ? Image.network(imageUrl,
                          width: 40, height: 40, fit: BoxFit.cover)
                      : Container(
                          width: 40,
                          height: 40,
                          color: const Color(0xFF212121),
                          child: const Icon(Icons.music_note,
                              color: Colors.grey, size: 20),
                        ),
                ),
                title: Text(trackName,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                subtitle: Text(artistName,
                    style: const TextStyle(
                        color: Colors.grey, fontSize: 13)),
                trailing: isProposeMode
                    ? const Icon(Icons.add_circle_outline,
                        color: Color(0xFF1DB954), size: 24)
                    : (rating != null
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(
                              rating,
                              (_) => const Icon(Icons.star,
                                  color: Color(0xFF1DB954), size: 14),
                            ),
                          )
                        : const Text('unrated',
                            style: TextStyle(
                                color: Colors.grey, fontSize: 12))),
                onTap: isProposeMode
                    ? () => _proposeSong(context, track)
                    : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SongDetailScreen(track: track),
                          ),
                        ),
              );
            },
          ),
        ),
        if (state.isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: CircularProgressIndicator(color: Color(0xFF1DB954)),
          ),
      ],
    );
  }
}

// ── Album tracks screen ───────────────────────────────────────────────────────

class _AlbumTracksScreen extends ConsumerWidget {
  final Map<String, dynamic> album;
  final List<Map<String, dynamic>> tracks;
  final String? groupId;

  const _AlbumTracksScreen({
    required this.album,
    required this.tracks,
    this.groupId,
  });

  Future<void> _proposeSong(BuildContext context, WidgetRef ref,
      Map<String, dynamic> track) async {
    if (groupId == null) return;
    final userId = ref.read(userProvider).value?['id'] as String?;
    if (userId == null) return;

    final songId = track['id'] as String? ?? '';
    final songName = track['name'] as String? ?? '';
    final artistName = (track['artists'] as List?)?.firstOrNull?['name']
            as String? ??
        '';
    final albumArt =
        (album['images'] as List?)?.firstOrNull?['url'] as String? ?? '';

    try {
      await FirestoreService().proposeSong(
        groupId: groupId!,
        songId: songId,
        songName: songName,
        artistName: artistName,
        albumArt: albumArt,
        proposedBy: userId,
      );
      if (!context.mounted) return;
      final nav = Navigator.of(context);
      nav.pop(); // album tracks screen
      nav.pop(); // library screen
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final albumName = album['name'] as String? ?? '';
    final artist =
        (album['artists'] as List?)?.firstOrNull?['name'] as String? ?? '';
    final imageUrl =
        (album['images'] as List?)?.firstOrNull?['url'] as String?;
    final isProposeMode = groupId != null;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          albumName,
          style: const TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          // Album header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                if (imageUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(imageUrl,
                        width: 72, height: 72, fit: BoxFit.cover),
                  )
                else
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: const Color(0xFF212121),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.album,
                        color: Colors.grey, size: 36),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(albumName,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text(artist,
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFF2A2A2A), height: 1),

          // Track list
          Expanded(
            child: tracks.isEmpty
                ? const Center(
                    child: Text('No liked songs from this album',
                        style: TextStyle(color: Colors.grey)),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    itemCount: tracks.length,
                    separatorBuilder: (_, __) =>
                        const Divider(color: Color(0xFF2A2A2A), height: 1),
                    itemBuilder: (context, index) {
                      final track = tracks[index];
                      final trackName = track['name'] as String? ?? '';
                      final trackArtist = (track['artists'] as List?)
                              ?.firstOrNull?['name'] as String? ??
                          artist;
                      final trackImageUrl =
                          ((track['album']?['images'] as List?)
                                  ?.firstOrNull as Map?)?['url'] as String?;

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 4, horizontal: 0),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: trackImageUrl != null
                              ? Image.network(trackImageUrl,
                                  width: 40, height: 40, fit: BoxFit.cover)
                              : Container(
                                  width: 40,
                                  height: 40,
                                  color: const Color(0xFF212121),
                                  child: const Icon(Icons.music_note,
                                      color: Colors.grey, size: 20),
                                ),
                        ),
                        title: Text(trackName,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 15),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        subtitle: Text(trackArtist,
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 13)),
                        trailing: isProposeMode
                            ? const Icon(Icons.add_circle_outline,
                                color: Color(0xFF1DB954), size: 24)
                            : null,
                        onTap: isProposeMode
                            ? () => _proposeSong(context, ref, track)
                            : () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        SongDetailScreen(track: track),
                                  ),
                                ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
