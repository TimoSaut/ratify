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
    // TODO: implement submitRating
    print('TODO: submitRating songId=$songId userId=$userId rating=$rating');
  }

  Future<List<Map<String, dynamic>>> getPendingVotes(String songId) async {
    // TODO: implement getPendingVotes
    print('TODO: getPendingVotes songId=$songId');
    return [];
  }
}
