import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  static const String usersCollection = 'users';
  static const String playlistsCollection = 'playlists';
  static const String songsCollection = 'songs';
  static const String ratingsCollection = 'ratings';
  static const String pendingVotesCollection = 'pendingVotes';

  Future<void> createOrUpdateUser(Map<String, dynamic> userData) async {
    // TODO: implement createOrUpdateUser
    print('TODO: createOrUpdateUser $userData');
  }

  Future<void> addPendingVote(
      String songId, Map<String, dynamic> voteData) async {
    // TODO: implement addPendingVote
    print('TODO: addPendingVote songId=$songId voteData=$voteData');
  }

  Future<void> submitRating(
      String songId, String userId, int rating) async {
    try {
      await FirebaseFirestore.instance
          .collection(ratingsCollection)
          .add({
        'songId': songId,
        'userId': userId,
        'rating': rating,
        'timestamp': DateTime.now(),
      });
    } catch (e) {
      print('submitRating error: $e');
      rethrow;
    }
  }

  Future<int?> getUserRatingForSong(String songId, String userId) async {
    final query = await FirebaseFirestore.instance
        .collection(ratingsCollection)
        .where('songId', isEqualTo: songId)
        .where('userId', isEqualTo: userId)
        .limit(1)
        .get();
    if (query.docs.isEmpty) return null;
    return query.docs.first.data()['rating'] as int?;
  }

  Future<void> updateRating(
      String songId, String userId, int rating) async {
    try {
      final query = await FirebaseFirestore.instance
          .collection(ratingsCollection)
          .where('songId', isEqualTo: songId)
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        await query.docs.first.reference.update({
          'rating': rating,
          'timestamp': DateTime.now(),
        });
      } else {
        await FirebaseFirestore.instance.collection(ratingsCollection).add({
          'songId': songId,
          'userId': userId,
          'rating': rating,
          'timestamp': DateTime.now(),
        });
      }
    } catch (e) {
      print('updateRating error: $e');
      rethrow;
    }
  }

  Future<Map<String, int>> getAllUserRatings(String userId) async {
    final query = await FirebaseFirestore.instance
        .collection(ratingsCollection)
        .where('userId', isEqualTo: userId)
        .get();
    final result = <String, int>{};
    for (final doc in query.docs) {
      final data = doc.data();
      final songId = data['songId'] as String?;
      final rating = data['rating'] as int?;
      if (songId != null && rating != null) {
        result[songId] = rating;
      }
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> getPendingVotes(String songId) async {
    // TODO: implement getPendingVotes
    print('TODO: getPendingVotes songId=$songId');
    return [];
  }
}
