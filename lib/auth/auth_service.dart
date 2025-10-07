import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;
import 'token_storage.dart';

class AuthService {
  final TokenStorage tokenStorage;

  AuthService({required this.tokenStorage});

  static const clientId = "f58b9e4fc6ec4df3ad283efe8cc5f9c9";
  static const redirectUri = "com.rateify.app://callback";
  static const scopes = "user-read-email playlist-modify-public";

  Future<void> login() async {
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
    if (code == null) throw Exception("Authorization code not found");

    final tokenUrl = Uri.https('accounts.spotify.com', '/api/token');
    final tokenBody = {
      'client_id': clientId,
      'grant_type': 'authorization_code',
      'code': code,
      'redirect_uri': redirectUri,
      'code_verifier': codeVerifier,
    };

    final tokenResponse = await http.post(
      tokenUrl,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: tokenBody,
    );

    if (tokenResponse.statusCode != 200) {
      throw Exception("Failed to get access token: ${tokenResponse.body}");
    }

    final tokenJson = json.decode(tokenResponse.body);
    final accessToken = tokenJson['access_token'] as String?;
    final refreshToken = tokenJson['refresh_token'] as String?;

    if (accessToken == null || refreshToken == null) {
      throw Exception("Tokens not found in response");
    }

    await tokenStorage.saveTokens(accessToken, refreshToken);
  }

  Future<void> refreshToken() async {
    final refreshToken = await tokenStorage.getRefreshToken();
    if (refreshToken == null) return;

    final tokenUrl = Uri.https('accounts.spotify.com', '/api/token');
    final tokenBody = {
      'client_id': clientId,
      'grant_type': 'refresh_token',
      'refresh_token': refreshToken,
    };

    final tokenResponse = await http.post(
      tokenUrl,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: tokenBody,
    );

    if (tokenResponse.statusCode != 200) {
      throw Exception("Failed to refresh token: ${tokenResponse.body}");
    }

    final tokenJson = json.decode(tokenResponse.body);
    final accessToken = tokenJson['access_token'] as String?;
    if (accessToken != null) {
      final currentRefresh = refreshToken;
      await tokenStorage.saveTokens(accessToken, currentRefresh);
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
}