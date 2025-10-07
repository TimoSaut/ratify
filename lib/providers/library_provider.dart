import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

class Song {
  final String title;
  Song(this.title);
}

class LibraryState extends StateNotifier<List<Song>> {
  LibraryState() : super([]);

  void addSong(Song song) => state = [...state, song];
  void removeSong(Song song) => state = state.where((s) => s != song).toList();
}

final libraryProvider = StateNotifierProvider<LibraryState, List<Song>>((ref) => LibraryState());