import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthStateNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setLoggedIn() => state = true;
  void setLoggedOut() => state = false;
}

final authStateProvider = NotifierProvider<AuthStateNotifier, bool>(
  AuthStateNotifier.new,
);
