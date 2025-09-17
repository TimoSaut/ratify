import 'package:flutter/material.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  Future<void> _loginWithSpotify(BuildContext context) async {
    try {
      const clientId = "f58b9e4fc6ec4df3ad283efe8cc5f9c9";
      const redirectUri = "com.rateify.app://callback";
      const scopes = "user-read-email playlist-modify-public";

      final url =
          "https://accounts.spotify.com/authorize?response_type=token&client_id=$clientId&redirect_uri=$redirectUri&scope=$scopes";

      // Browser öffnen
      final result = await FlutterWebAuth2.authenticate(
        url: url,
        callbackUrlScheme: "com.rateify.app"
      );

      // Token auslesen
      final accessToken = Uri.parse(result).fragment
          .split("&")
          .firstWhere((e) => e.startsWith("access_token="))
          .split("=")[1];

      // Debug: Token ausgeben
      // → in echt würdest du es speichern und für API Calls nutzen
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Spotify Access Token: $accessToken")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Login failed: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  backgroundColor: const Color(0xFF1DB954), // Spotify Grün
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                onPressed: () => _loginWithSpotify(context),
                child: const Text(
                  "Connect with Spotify",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}