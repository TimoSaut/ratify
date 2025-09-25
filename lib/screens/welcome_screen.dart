import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;
import 'package:rateify/screens/main_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _isLoggingIn = false;

  Future<void> _loginWithSpotify(BuildContext context) async {
    if (_isLoggingIn) return;
    setState(() {
      _isLoggingIn = true;
    });

    try {
      const clientId = "f58b9e4fc6ec4df3ad283efe8cc5f9c9";
      const redirectUri = "com.rateify.app://callback";
      const scopes = "user-read-email playlist-modify-public";

      final codeVerifier = _generateCodeVerifier();
      final codeChallenge = _generateCodeChallenge(codeVerifier);

      final authUrl = Uri.https('accounts.spotify.com', '/authorize', {
        'client_id': clientId,
        'response_type': 'code',
        'redirect_uri': redirectUri,
        'scope': scopes,
        'code_challenge_method': 'S256',
        'code_challenge': codeChallenge,
      });

      final result = await FlutterWebAuth2.authenticate(
        url: authUrl.toString(),
        callbackUrlScheme: Uri.parse(redirectUri).scheme,
      );

      final code = Uri.parse(result).queryParameters['code'];
      if (code == null || code.isEmpty) {
        throw Exception("Authorization code not found in response: $result");
      }

      if (kDebugMode) {
        print('--- Spotify Login Debug ---');
        print('Authorization Code: $code');
        print('Code Verifier: $codeVerifier');
        print('CodeChallenge: $codeChallenge');
        print('Redirect URI: $redirectUri');
        print('--- End of Debug ---');
      }

      final tokenUrl = Uri.https('accounts.spotify.com', '/api/token');
      final tokenBody = {
        'client_id': clientId,
        'grant_type': 'authorization_code',
        'code': code,
        'redirect_uri': redirectUri,
        'code_verifier': codeVerifier,
      };

      if (kDebugMode) {
        print('POST Request to $tokenUrl with body: $tokenBody');
      }

      final tokenResponse = await http.post(
        tokenUrl,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: tokenBody,
      );

      if (kDebugMode) {
        print(
          'Response from Spotify: ${tokenResponse.statusCode} ${tokenResponse.body}',
        );
      }

      if (tokenResponse.statusCode != 200) {
        final errorJson = json.decode(tokenResponse.body);
        throw Exception(
          "Failed to get access token: ${errorJson['error_description'] ?? tokenResponse.body}",
        );
      }

      final tokenJson = json.decode(tokenResponse.body);
      final accessToken = tokenJson['access_token'] as String?;

      if (accessToken == null || accessToken.isEmpty) {
        throw Exception("Access token not found in token response");
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainScreen()),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Login failed: $e")));
    } finally {
      setState(() {
        _isLoggingIn = false;
      });
    }
  }

  String _generateCodeVerifier() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~';
    final random = Random.secure();
    return String.fromCharCodes(
      Iterable.generate(
        128,
        (_) => chars.codeUnitAt(random.nextInt(chars.length)),
      ),
    );
  }

  String _generateCodeChallenge(String codeVerifier) {
    final bytes = utf8.encode(codeVerifier);
    final digest = sha256.convert(bytes);
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
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
                  backgroundColor: const Color(0xFF1DB954),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 15,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                onPressed: _isLoggingIn
                    ? null
                    : () => _loginWithSpotify(context),
                child: const Text(
                  "Connect with Spotify",
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
