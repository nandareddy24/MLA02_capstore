import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../core/constants/app_constants.dart';

/// SQLite persistence layer powering offline-first devices, fault reports,
/// diagnosis records, feedback logs, and user profiles.
class LocalDatabaseService {
  LocalDatabaseService({this.databasePathOverride});

  final String? databasePathOverride;
  Database? _database;

  static const String tableUsers = 'users';
  static const String tableDevices = 'devices';
  static const String tableFaultReports = 'fault_reports';
  static const String tableDiagnosisResults = 'diagnosis_results';
  static const String tableFeedback = 'feedback';

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }
    _database = await _openDatabase();
    return _database!;
  }

  Future<Database> _openDatabase() async {
    final String path;
    if (databasePathOverride != null) {
      path = databasePathOverride!;
    } else {
      final dbDir = await getDatabasesPath();
      path = p.join(dbDir, AppConstants.databaseName);
    }

    return openDatabase(
      path,
      version: AppConstants.databaseVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableUsers (
        id TEXT PRIMARY KEY,
        full_name TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        role TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableDevices (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        manufacturer TEXT NOT NULL,
        model_number TEXT NOT NULL,
        serial_number TEXT,
        location TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableFaultReports (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL DEFAULT '',
        device_id TEXT NOT NULL,
        device_name TEXT NOT NULL,
        device_category TEXT,
        manufacturer TEXT,
        model_name TEXT,
        device_age TEXT,
        operating_environment TEXT,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        symptoms_json TEXT NOT NULL,
        severity TEXT NOT NULL,
        status TEXT NOT NULL,
        error_code TEXT,
        started_when TEXT,
        operating_conditions TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableDiagnosisResults (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL DEFAULT '',
        report_id TEXT NOT NULL UNIQUE,
        device_name TEXT,
        primary_fault TEXT NOT NULL,
        confidence REAL,
        confidence_is_calibrated INTEGER NOT NULL DEFAULT 0,
        severity TEXT NOT NULL DEFAULT 'medium',
        severity_rationale TEXT,
        summary TEXT NOT NULL,
        model_version TEXT NOT NULL,
        algorithm TEXT,
        processing_time_ms REAL,
        ranked_alternatives_json TEXT NOT NULL DEFAULT '[]',
        evidence_json TEXT NOT NULL DEFAULT '[]',
        contributing_factors_json TEXT NOT NULL,
        is_uncertain INTEGER NOT NULL DEFAULT 0,
        uncertainty_message TEXT,
        disclaimer TEXT,
        recommendations_json TEXT NOT NULL,
        decision_support_plan_json TEXT,
        analyzed_at TEXT NOT NULL,
        FOREIGN KEY (report_id) REFERENCES $tableFaultReports (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableFeedback (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL DEFAULT '',
        diagnosis_id TEXT,
        report_id TEXT NOT NULL,
        diagnosis_relevance TEXT NOT NULL DEFAULT 'yes',
        resolution_status TEXT NOT NULL DEFAULT 'not_attempted',
        was_helpful INTEGER NOT NULL DEFAULT 1,
        was_issue_resolved INTEGER NOT NULL,
        still_needs_professional_assistance INTEGER NOT NULL DEFAULT 0,
        rating INTEGER NOT NULL,
        comments TEXT NOT NULL,
        submitted_at TEXT NOT NULL,
        FOREIGN KEY (report_id) REFERENCES $tableFaultReports (id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE $tableFaultReports ADD COLUMN device_category TEXT',
      );
      await db.execute(
        'ALTER TABLE $tableFaultReports ADD COLUMN manufacturer TEXT',
      );
      await db.execute(
        'ALTER TABLE $tableFaultReports ADD COLUMN model_name TEXT',
      );
      await db.execute(
        'ALTER TABLE $tableFaultReports ADD COLUMN device_age TEXT',
      );
      await db.execute(
        'ALTER TABLE $tableFaultReports ADD COLUMN operating_environment TEXT',
      );
      await db.execute(
        'ALTER TABLE $tableFaultReports ADD COLUMN started_when TEXT',
      );
    }
    if (oldVersion < 3) {
      await db.execute(
        'ALTER TABLE $tableDiagnosisResults ADD COLUMN device_name TEXT',
      );
      await db.execute(
        'ALTER TABLE $tableDiagnosisResults ADD COLUMN confidence_is_calibrated INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        "ALTER TABLE $tableDiagnosisResults ADD COLUMN severity TEXT NOT NULL DEFAULT 'medium'",
      );
      await db.execute(
        'ALTER TABLE $tableDiagnosisResults ADD COLUMN severity_rationale TEXT',
      );
      await db.execute(
        'ALTER TABLE $tableDiagnosisResults ADD COLUMN algorithm TEXT',
      );
      await db.execute(
        'ALTER TABLE $tableDiagnosisResults ADD COLUMN processing_time_ms REAL',
      );
      await db.execute(
        "ALTER TABLE $tableDiagnosisResults ADD COLUMN ranked_alternatives_json TEXT NOT NULL DEFAULT '[]'",
      );
      await db.execute(
        "ALTER TABLE $tableDiagnosisResults ADD COLUMN evidence_json TEXT NOT NULL DEFAULT '[]'",
      );
      await db.execute(
        'ALTER TABLE $tableDiagnosisResults ADD COLUMN is_uncertain INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE $tableDiagnosisResults ADD COLUMN uncertainty_message TEXT',
      );
      await db.execute(
        'ALTER TABLE $tableDiagnosisResults ADD COLUMN disclaimer TEXT',
      );
    }
    if (oldVersion < 4) {
      await db.execute(
        'ALTER TABLE $tableDiagnosisResults ADD COLUMN decision_support_plan_json TEXT',
      );
      await db.execute(
        'ALTER TABLE $tableFeedback ADD COLUMN diagnosis_id TEXT',
      );
      await db.execute(
        'ALTER TABLE $tableFeedback ADD COLUMN was_helpful INTEGER NOT NULL DEFAULT 1',
      );
      await db.execute(
        'ALTER TABLE $tableFeedback ADD COLUMN still_needs_professional_assistance INTEGER NOT NULL DEFAULT 0',
      );
    }
    if (oldVersion < 5) {
      await db.execute(
        "ALTER TABLE $tableFaultReports ADD COLUMN user_id TEXT NOT NULL DEFAULT ''",
      );
      await db.execute(
        "ALTER TABLE $tableDiagnosisResults ADD COLUMN user_id TEXT NOT NULL DEFAULT ''",
      );
      await db.execute(
        "ALTER TABLE $tableFeedback ADD COLUMN user_id TEXT NOT NULL DEFAULT ''",
      );
      await db.execute(
        "ALTER TABLE $tableFeedback ADD COLUMN diagnosis_relevance TEXT NOT NULL DEFAULT 'yes'",
      );
      await db.execute(
        "ALTER TABLE $tableFeedback ADD COLUMN resolution_status TEXT NOT NULL DEFAULT 'not_attempted'",
      );
    }
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
