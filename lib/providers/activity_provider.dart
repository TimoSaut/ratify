import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

class ActivityState extends StateNotifier<List<String>> {
  ActivityState() : super([]);

  void addActivity(String text) => state = [...state, text];
}

final activityProvider = StateNotifierProvider<ActivityState, List<String>>((ref) => ActivityState());