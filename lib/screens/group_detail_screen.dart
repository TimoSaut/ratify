import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import 'library_screen.dart';
import '../providers/spotify_provider.dart';
import '../services/firestore_service.dart';

// ── Provider ──────────────────────────────────────────────────────────────────

final _groupDetailProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>?, String>((ref, groupId) async {
  final doc = await FirebaseFirestore.instance
      .collection('groups')
      .doc(groupId)
      .get();
  if (!doc.exists) return null;
  return {'id': doc.id, ...doc.data()!};
});

// ── Screen ────────────────────────────────────────────────────────────────────

class GroupDetailScreen extends ConsumerWidget {
  final String groupId;
  final String playlistName;

  const GroupDetailScreen({
    super.key,
    required this.groupId,
    required this.playlistName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupAsync = ref.watch(_groupDetailProvider(groupId));
    final userId = ref.watch(userProvider).value?['id'] as String?;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(
          playlistName,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: groupAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFF1DB954)),
        ),
        error: (e, _) => Center(
          child: Text('Error: $e',
              style: const TextStyle(color: Colors.grey)),
        ),
        data: (group) {
          if (group == null) {
            return const Center(
              child: Text('Group not found',
                  style: TextStyle(color: Colors.grey)),
            );
          }
          return _GroupDetailBody(group: group, userId: userId);
        },
      ),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _GroupDetailBody extends StatelessWidget {
  final Map<String, dynamic> group;
  final String? userId;

  const _GroupDetailBody({required this.group, required this.userId});

  @override
  Widget build(BuildContext context) {
    final name = group['name'] as String? ?? 'Untitled';
    final groupId = group['id'] as String? ?? '';
    final members = (group['members'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    final inviteCode = group['inviteCode'] as String? ?? '';

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      children: [
        // ── Header ───────────────────────────────────────────────────────
        _PlaylistHeader(name: name, memberCount: members.length),
        const SizedBox(height: 28),

        // ── Members ──────────────────────────────────────────────────────
        _sectionTitle('Members'),
        const SizedBox(height: 12),
        _MembersRow(members: members),
        const SizedBox(height: 12),
        _InviteButton(inviteCode: inviteCode),
        const SizedBox(height: 28),

        // ── Pending Votes ─────────────────────────────────────────────────
        _sectionTitle('Pending Votes'),
        const SizedBox(height: 12),
        _emptyCard('No pending votes yet'),
        const SizedBox(height: 12),
        _ProposeSongButton(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LibraryScreen()),
          ),
        ),
        const SizedBox(height: 28),

        // ── Recent Activity ───────────────────────────────────────────────
        _sectionTitle('Recent Activity'),
        const SizedBox(height: 12),
        _emptyCard('No activity yet'),
        const SizedBox(height: 28),

        // ── Leave Group ───────────────────────────────────────────────────
        if (userId != null)
          _LeaveGroupButton(groupId: groupId, userId: userId!),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 17,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _emptyCard(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: const TextStyle(color: Colors.grey, fontSize: 14),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _PlaylistHeader extends StatelessWidget {
  final String name;
  final int memberCount;

  const _PlaylistHeader({required this.name, required this.memberCount});

  @override
  Widget build(BuildContext context) {
    final memberLabel =
        '$memberCount ${memberCount == 1 ? 'member' : 'members'}';

    return Column(
      children: [
        // Cover art placeholder
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: const Color(0xFF1DB954).withOpacity(0.15),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.library_music,
            color: Color(0xFF1DB954),
            size: 52,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),
        Text(
          memberLabel,
          style: const TextStyle(color: Colors.grey, fontSize: 14),
        ),
      ],
    );
  }
}

// ── Members row ───────────────────────────────────────────────────────────────

class _MembersRow extends StatelessWidget {
  final List<String> members;
  static const _maxVisible = 5;

  const _MembersRow({required this.members});

  @override
  Widget build(BuildContext context) {
    final visible = members.take(_maxVisible).toList();
    final overflow = members.length - _maxVisible;

    return Row(
      children: [
        ...visible.map((id) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _MemberAvatar(userId: id),
            )),
        if (overflow > 0)
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.grey[800],
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '+$overflow',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _MemberAvatar extends StatelessWidget {
  final String userId;

  const _MemberAvatar({required this.userId});

  @override
  Widget build(BuildContext context) {
    // Members are stored as Spotify user IDs; no display name available yet.
    // Show a placeholder avatar with the first character of the ID.
    final initial =
        userId.isNotEmpty ? userId[0].toUpperCase() : '?';

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFF1DB954).withOpacity(0.2),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            color: Color(0xFF1DB954),
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

// ── Invite button ─────────────────────────────────────────────────────────────

class _InviteButton extends StatelessWidget {
  final String inviteCode;

  const _InviteButton({required this.inviteCode});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF1DB954),
          side: const BorderSide(color: Color(0xFF1DB954)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        icon: const Icon(Icons.person_add_outlined),
        label: const Text(
          'Invite Member',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        onPressed: inviteCode.isEmpty
            ? null
            : () async {
                final box =
                    context.findRenderObject() as RenderBox?;
                await Share.share(
                  'Join my Rateify group: rateify://join/$inviteCode',
                  sharePositionOrigin: box != null
                      ? box.localToGlobal(Offset.zero) & box.size
                      : Rect.largest,
                );
              },
      ),
    );
  }
}

// ── Leave group button ────────────────────────────────────────────────────────

class _LeaveGroupButton extends StatelessWidget {
  final String groupId;
  final String userId;

  const _LeaveGroupButton({
    required this.groupId,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red,
          side: const BorderSide(color: Colors.red),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        icon: const Icon(Icons.exit_to_app),
        label: const Text(
          'Leave Group',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        onPressed: () => _confirmLeave(context),
      ),
    );
  }

  void _confirmLeave(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Leave Group',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to leave this group?',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await FirestoreService().leaveGroup(groupId, userId);
                if (!context.mounted) return;
                Navigator.pop(context);
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            child: const Text('Leave',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// ── Propose song button ───────────────────────────────────────────────────────

class _ProposeSongButton extends StatelessWidget {
  final VoidCallback onTap;

  const _ProposeSongButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1DB954),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: 0,
        ),
        icon: const Icon(Icons.music_note_outlined),
        label: const Text(
          'Propose a Song',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        onPressed: onTap,
      ),
    );
  }
}
