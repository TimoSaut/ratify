import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/navigation_provider.dart';
import '../providers/auth_state_provider.dart';
import 'activity_screen.dart';
import 'library_screen.dart';
import 'dashboard_screen.dart';
import 'welcome_screen.dart';

class MainScreen extends ConsumerWidget {
  const MainScreen({super.key});

  static const List<Widget> _screens = [
    DashboardScreen(),
    ActivityScreen(),
    LibraryScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<bool>(authStateProvider, (_, isLoggedIn) {
      if (!isLoggedIn) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const WelcomeScreen()),
          (route) => false,
        );
      }
    });

    final currentIndex = ref.watch(navigationIndexProvider);

    return Scaffold(
      body: Container(
        color: Colors.black,
        child: _screens[currentIndex],
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.black,
        currentIndex: currentIndex,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.grey,
        onTap: (index) => ref.read(navigationIndexProvider.notifier).state = index,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: "Home",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.library_music),
            label: "Playlists",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.music_note),
            label: "Library",
          ),
        ],
      ),
    );
  }
}
