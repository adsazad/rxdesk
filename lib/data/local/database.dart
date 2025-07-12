import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'database.g.dart';

// Patients table definition
class Patients extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 64)();
  TextColumn get gender => text().withLength(min: 1, max: 16)();
  TextColumn get mobile => text().withLength(min: 1, max: 16)();
  IntColumn get age => integer()();
  RealColumn get height => real()(); // Height in cm
  RealColumn get weight => real()(); // Weight in kg
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class Recordings extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get patientId => integer()(); // Foreign key to Patients.id
  TextColumn get filePath => text().withLength(min: 1, max: 255)();
  DateTimeColumn get recordedAt =>
      dateTime().withDefault(currentDateAndTime)(); // <-- Added field
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DriftDatabase(tables: [Patients, Recordings])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 2; // <-- Increment this

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from == 1) {
        await m.addColumn(recordings, recordings.recordedAt);
      }
    },
  );
}

// Opens the database connection
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'app.sqlite'));
    return NativeDatabase(file);
  });
}
