import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rateify/screens/main_screen.dart';
import 'package:rateify/providers/activity_provider.dart';
import 'package:rateify/providers/auth_provider.dart';

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  Future<void> _handleLogin(WidgetRef ref, BuildContext context) async {
    final authService = ref.read(authServiceProvider);
    final isLoggingIn = ref.read(isLoggingInProvider.notifier);
    final isLoggedIn = ref.read(isLoggedInProvider.notifier);

    if (ref.read(isLoggingInProvider)) return;

    isLoggingIn.state = true;
    try {
      await authService.login();
      isLoggedIn.state = true;

      if (context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainScreen()),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Login failed: $e")),
        );
      }
    } finally {
      isLoggingIn.state = false;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoggingIn = ref.watch(isLoggingInProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "Hello! WELCOME to RATEIFY",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 50),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1DB954),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 15,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                onPressed: isLoggingIn
                    ? null
                    : () => _handleLogin(ref, context),
                child: Text(
                  isLoggingIn
                      ? "Connecting..."
                      : "Connect with Spotify",
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}