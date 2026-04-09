import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'settings_screen.dart';
import 'groups_screen.dart';
import '../providers/spotify_provider.dart';
import '../providers/navigation_provider.dart';
import '../services/firestore_service.dart';

final _homeGroupsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final userId = ref.watch(userProvider).value?['id'] as String?;
  if (userId == null) return [];
  return FirestoreService().getGroupsForUser(userId);
});

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProvider);
    final profileImageUrl =
        (userAsync.value?['images'] as List?)?.firstOrNull?['url'] as String?;
    final groupsAsync = ref.watch(_homeGroupsProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        leading: GestureDetector(
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
        title: const Text(
          'Home',
          style: TextStyle(
              color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Greeting ────────────────────────────────────────────────────
            userAsync.when(
              loading: () => const SizedBox(
                height: 36,
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Color(0xFF1DB954)),
                  ),
                ),
              ),
              error: (_, __) => const Text(
                'Hey there 👋',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold),
              ),
              data: (user) => Text(
                'Hey ${user['display_name'] ?? 'there'} 👋',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 28),

            // ── Pending Votes ────────────────────────────────────────────────
            const Text(
              'Pending Votes',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF2A2A2A)),
              ),
              child: const Column(
                children: [
                  Text(
                    'No pending votes 🎉',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 6),
                  Text(
                    "You're all caught up",
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // ── Recent Activity ──────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Activity',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () => ref
                      .read(navigationIndexProvider.notifier)
                      .state = 1,
                  child: const Text(
                    'Show all →',
                    style:
                        TextStyle(color: Color(0xFF1DB954), fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF2A2A2A)),
              ),
              child: const Text(
                'No activity yet',
                style: TextStyle(color: Colors.grey, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 32),

            // ── Your Groups ──────────────────────────────────────────────────
            const Text(
              'Your Groups',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            groupsAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: CircularProgressIndicator(
                      color: Color(0xFF1DB954)),
                ),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text('Error: $e',
                    style: const TextStyle(color: Colors.grey)),
              ),
              data: (groups) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (groups.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          vertical: 28, horizontal: 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(16),
                        border:
                            Border.all(color: const Color(0xFF2A2A2A)),
                      ),
                      child: const Text(
                        'No groups yet',
                        style:
                            TextStyle(color: Colors.grey, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    ...groups.map((group) {
                      final name = group['name'] as String? ?? '';
                      final inviteCode =
                          group['inviteCode'] as String? ?? '';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                            vertical: 14, horizontal: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: const Color(0xFF2A2A2A)),
                        ),
                        child: Row(
                          children: [
                            const CircleAvatar(
                              radius: 20,
                              backgroundColor: Color(0xFF1DB954),
                              child: Icon(Icons.group,
                                  color: Colors.white, size: 20),
                            ),
                            const SizedBox(width: 14),
                            Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  inviteCode,
                                  style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                  const SizedBox(height: 4),
                  TextButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const GroupsScreen()),
                    ),
                    icon: const Icon(Icons.add,
                        color: Color(0xFF1DB954), size: 18),
                    label: const Text(
                      'Create Group',
                      style: TextStyle(
                          color: Color(0xFF1DB954), fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
