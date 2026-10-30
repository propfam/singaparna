import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/expense.dart';

class DatabaseHelper {
  DatabaseHelper._();

  static final DatabaseHelper instance = DatabaseHelper._();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'singaparna.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE expenses (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            amount INTEGER NOT NULL,
            category TEXT NOT NULL,
            date TEXT NOT NULL
          )
        ''');
      },
    );
  }

  // Add expense
  Future<int> insertExpense(Expense expense) async {
    final db = await database;

    final data = expense.toMap()..remove('id');

    return db.insert('expenses', data);
  }

  // Get all expenses
  Future<List<Expense>> getExpenses() async {
    final db = await database;

    final maps = await db.query(
      'expenses',
      orderBy: 'date DESC, id DESC',
    );

    return maps.map(Expense.fromMap).toList();
  }

  // Update expense
  Future<int> updateExpense(Expense expense) async {
    if (expense.id == null) {
      throw ArgumentError('ID transaksi tidak boleh null.');
    }

    final db = await database;

    return db.update(
      'expenses',
      expense.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [expense.id],
    );
  }

  // Delete expense
  Future<int> deleteExpense(int id) async {
    final db = await database;

    return db.delete(
      'expenses',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
