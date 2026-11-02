import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

@DataClassName('DuaRecord')
class DuaRecords extends Table {
  TextColumn get id => text()();
  TextColumn get arabic => text()();
  TextColumn get transliteration => text()();
  TextColumn get translation => text()();
  TextColumn get benefits => text()();
  TextColumn get occasion => text().nullable()();
  TextColumn get sourcesJson => text()();
  TextColumn get assignedDay => text()();
  TextColumn get status => text()();
  DateTimeColumn get generatedAt => dateTime()();
  DateTimeColumn get recitedAt => dateTime().nullable()();
  BoolColumn get flagged => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {assignedDay},
  ];
}

@DriftDatabase(tables: [DuaRecords])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  AppDatabase.defaults()
    : super(
        driftDatabase(
          name: 'ayyam',
          native: const DriftNativeOptions(shareAcrossIsolates: true),
          web: DriftWebOptions(
            sqlite3Wasm: Uri.parse('sqlite3.wasm'),
            driftWorker: Uri.parse('drift_worker.js'),
          ),
        ),
      );

  @override
  int get schemaVersion => 1;
}
