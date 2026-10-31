import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// On-device cache for non-secret RunFuel data.
///
/// Provider credentials and health-document contents must never be stored here.
/// Health files require a separate encrypted vault before persistence is enabled.
class RunFuelDatabase {
  RunFuelDatabase._();

  static final RunFuelDatabase instance = RunFuelDatabase._();
  Database? _database;

  Future<void> initialize() async {
    if (_database != null) return;

    final root = await getDatabasesPath();
    _database = await openDatabase(
      p.join(root, 'runfuel_v1.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE activities (
            id TEXT PRIMARY KEY,
            started_at TEXT NOT NULL,
            sport TEXT,
            distance_m REAL,
            duration_s REAL,
            avg_hr REAL,
            avg_pace_s_per_km REAL,
            source_updated_at TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE nutrition_days (
            day TEXT PRIMARY KEY,
            calories REAL,
            protein_g REAL,
            carbs_g REAL,
            fat_g REAL,
            fibre_g REAL,
            source_updated_at TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE coaching_reviews (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            created_at TEXT NOT NULL,
            prompt TEXT,
            response TEXT NOT NULL,
            model TEXT,
            input_tokens INTEGER,
            output_tokens INTEGER
          )
        ''');

        await db.execute('''
          CREATE TABLE sync_state (
            source TEXT PRIMARY KEY,
            last_attempt TEXT,
            last_success TEXT,
            status TEXT NOT NULL,
            message TEXT
          )
        ''');
      },
    );
  }

  Future<Database> get database async {
    final db = _database;
    if (db == null) {
      throw StateError('RunFuelDatabase.initialize() must be called first.');
    }
    return db;
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
