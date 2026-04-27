import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../models/reminder.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  DatabaseHelper._internal();

  factory DatabaseHelper() => _instance;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final directory = await getApplicationDocumentsDirectory();
    final path = join(directory.path, 'reminders.db');
    return await openDatabase(
      path,
      version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE reminders(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        hour INTEGER,
        minute INTEGER,
        days TEXT,
        isEnabled INTEGER,
        soundPath TEXT,
        type INTEGER,
        customDate INTEGER,
        itemType INTEGER DEFAULT 0,
        isCompleted INTEGER DEFAULT 0,
        completedDate INTEGER,
        dueDate INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE punch_records(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        reminderId INTEGER,
        punchTime INTEGER,
        FOREIGN KEY (reminderId) REFERENCES reminders(id)
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE reminders ADD COLUMN itemType INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE reminders ADD COLUMN isCompleted INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE reminders ADD COLUMN dueDate INTEGER');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE reminders ADD COLUMN completedDate INTEGER');
    }
  }

  Future<int> insertReminder(Reminder reminder) async {
    final db = await database;
    final values = Map<String, dynamic>.from(reminder.toMap())..remove('id');
    return await db.insert('reminders', values);
  }

  Future<List<Reminder>> getReminders() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('reminders');
    return List.generate(maps.length, (i) {
      return Reminder.fromMap(maps[i]);
    });
  }

  Future<int> updateReminder(Reminder reminder) async {
    final db = await database;
    return await db.update(
      'reminders',
      reminder.toMap(),
      where: 'id = ?',
      whereArgs: [reminder.id],
    );
  }

  Future<int> markAsCompleted(int id, bool completed) async {
    final db = await database;
    return await db.update(
      'reminders',
      {
        'isCompleted': completed ? 1 : 0,
        'completedDate': completed ? DateTime.now().millisecondsSinceEpoch : null,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteReminder(int id) async {
    final db = await database;
    return await db.delete(
      'reminders',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> insertPunchRecord(int reminderId, DateTime punchTime) async {
    final db = await database;
    return await db.insert('punch_records', {
      'reminderId': reminderId,
      'punchTime': punchTime.millisecondsSinceEpoch,
    });
  }

  Future<List<DateTime>> getPunchRecords(int reminderId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'punch_records',
      where: 'reminderId = ?',
      whereArgs: [reminderId],
    );
    return maps.map((map) => DateTime.fromMillisecondsSinceEpoch(map['punchTime'])).toList();
  }
}
