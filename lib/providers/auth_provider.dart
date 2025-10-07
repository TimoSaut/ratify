import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../auth/auth_service.dart';
import '../auth/token_storage.dart';

final authServiceProvider = Provider<AuthService>(
  (ref) => AuthService(tokenStorage: TokenStorage()),
);

final isLoggedInProvider = StateProvider<bool>((ref) => false);
final isLoggingInProvider = StateProvider<bool>((ref) => false);