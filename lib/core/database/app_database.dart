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

@DataClassName('PrayerDayRecord')
class PrayerDayRecords extends Table {
  TextColumn get day => text()();
  TextColumn get status => text()();
  BoolColumn get estimated => boolean().withDefault(const Constant(false))();
  DateTimeColumn get recordedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {day};
}

@DataClassName('MakeupDebtRecord')
class MakeupDebtRecords extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get sourceDay => text().nullable()();
  TextColumn get origin => text()();
  IntColumn get completedSteps => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get repaidAt => dateTime().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {sourceDay},
  ];
}

@DataClassName('LifeMetadataRecord')
class LifeMetadataRecords extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(
  tables: [
    DuaRecords,
    PrayerDayRecords,
    MakeupDebtRecords,
    LifeMetadataRecords,
  ],
)
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
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => migrator.createAll(),
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.createTable(prayerDayRecords);
        await migrator.createTable(makeupDebtRecords);
        await migrator.createTable(lifeMetadataRecords);
      }
    },
  );
}
