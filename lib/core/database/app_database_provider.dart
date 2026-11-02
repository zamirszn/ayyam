import 'dart:async';

import 'package:ayyam/core/database/app_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase.defaults();
  ref.onDispose(() => unawaited(database.close()));
  return database;
});
