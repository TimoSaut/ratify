import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  static const String usersCollection = 'users';
  static const String groupsCollection = 'groups';
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

  Future<String> createGroup(
      String name, String spotifyPlaylistId, String userId,
      {String? coverUrl}) async {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rng = Random.secure();
    final inviteCode =
        List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();

    final doc = await FirebaseFirestore.instance
        .collection(groupsCollection)
        .add({
      'name': name,
      'spotifyPlaylistId': spotifyPlaylistId,
      'members': [userId],
      'inviteCode': inviteCode,
      'createdAt': FieldValue.serverTimestamp(),
      if (coverUrl != null) 'coverUrl': coverUrl,
    });
    return doc.id;
  }

  Future<String> joinGroup(String inviteCode, String userId) async {
    final query = await FirebaseFirestore.instance
        .collection(groupsCollection)
        .where('inviteCode', isEqualTo: inviteCode)
        .limit(1)
        .get();
    if (query.docs.isEmpty) {
      throw Exception('Group not found');
    }
    final doc = query.docs.first;
    final members = List<String>.from(doc.data()['members'] as List? ?? []);
    if (members.contains(userId)) {
      throw Exception('Already a member');
    }
    await doc.reference.update({
      'members': FieldValue.arrayUnion([userId]),
    });
    return doc.data()['name'] as String? ?? '';
  }

  Future<List<Map<String, dynamic>>> getGroupsForUser(String userId) async {
    final query = await FirebaseFirestore.instance
        .collection(groupsCollection)
        .where('members', arrayContains: userId)
        .get();
    return query.docs
        .map((doc) => {'id': doc.id, ...doc.data()})
        .toList();
  }

  Future<void> leaveGroup(String groupId, String userId) async {
    final ref = FirebaseFirestore.instance
        .collection(groupsCollection)
        .doc(groupId);
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final doc = await transaction.get(ref);
      if (!doc.exists) return;
      final members =
          List<String>.from(doc.data()?['members'] as List? ?? []);
      members.remove(userId);
      if (members.isEmpty) {
        transaction.delete(ref);
      } else {
        transaction.update(ref, {'members': members});
      }
    });
  }

  Future<List<Map<String, dynamic>>> getPendingVotes(String songId) async {
    // TODO: implement getPendingVotes
    print('TODO: getPendingVotes songId=$songId');
    return [];
  }
}
