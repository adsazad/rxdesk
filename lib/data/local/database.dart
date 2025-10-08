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

// Prescriptions table definition
class Prescriptions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get patientId => integer()(); // Foreign key to Patients.id
  TextColumn get diagnosis => text().withLength(min: 1, max: 500)();
  TextColumn get notes => text().nullable()();
  
  // Vitals
  TextColumn get bpSystolic => text().nullable()();
  TextColumn get bpDiastolic => text().nullable()();
  TextColumn get heartRate => text().nullable()();
  TextColumn get temperature => text().nullable()();
  TextColumn get spo2 => text().nullable()();
  
  TextColumn get customInstructions => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

// Medicines table definition  
class Medicines extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get prescriptionId => integer()(); // Foreign key to Prescriptions.id
  TextColumn get name => text().withLength(min: 1, max: 100)(); // Generic name
  TextColumn get strength => text().nullable()(); // e.g., 500mg
  TextColumn get dose => text().nullable()(); // e.g., 1 tablet
  TextColumn get frequency => text().nullable()(); // e.g., TID
  TextColumn get duration => text().nullable()(); // e.g., 7 days
  TextColumn get route => text().nullable()(); // e.g., Oral, IV
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DriftDatabase(tables: [Patients, Recordings, Prescriptions, Medicines])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 3; // <-- Increment this for prescription tables

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from == 1) {
        await m.addColumn(recordings, recordings.recordedAt);
      }
      if (from <= 2) {
        await m.createTable(prescriptions);
        await m.createTable(medicines);
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
