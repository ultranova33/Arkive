import 'dart:io';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  DatabaseHelper._internal();

  static final DatabaseHelper instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => instance;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final directory = await getApplicationDocumentsDirectory();
    final databasePath = join(directory.path, 'arkive_vault.db');

    return openDatabase(
      databasePath,
      version: 2,
      onCreate: (database, version) async {
        await database.execute('''
          CREATE TABLE documents (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            category TEXT NOT NULL,
            filePath TEXT NOT NULL,
            pageCount INTEGER NOT NULL,
            fileSize TEXT NOT NULL,
            createdAt TEXT NOT NULL
          )
        ''');
        await database.execute('''
          CREATE TABLE custom_categories (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL COLLATE NOCASE UNIQUE
          )
        ''');
      },
      onUpgrade: (database, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await database.execute('''
            CREATE TABLE custom_categories (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL COLLATE NOCASE UNIQUE
            )
          ''');
        }
      },
    );
  }

  Future<int> insertDocument(Map<String, dynamic> document) async {
    final database = await this.database;
    return database.insert('documents', document);
  }

  Future<List<Map<String, dynamic>>> getAllDocuments({
    String query = '',
    String category = '',
  }) async {
    final database = await this.database;
    final whereClauses = <String>[];
    final whereArguments = <String>[];

    if (query.trim().isNotEmpty) {
      whereClauses.add('LOWER(title) LIKE LOWER(?)');
      final searchPattern = '%${query.trim()}%';
      whereArguments.add(searchPattern);
    }

    if (category.trim().isNotEmpty) {
      whereClauses.add('LOWER(category) = LOWER(?)');
      whereArguments.add(category.trim());
    }

    return database.query(
      'documents',
      where: whereClauses.isEmpty ? null : whereClauses.join(' AND '),
      whereArgs: whereArguments.isEmpty ? null : whereArguments,
      orderBy: 'createdAt DESC',
    );
  }

  Future<List<String>> getCustomCategories() async {
    final database = await this.database;
    final rows = await database.query(
      'custom_categories',
      columns: ['name'],
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows.map((row) => row['name']! as String).toList();
  }

  Future<bool> addCustomCategory(String name) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      return false;
    }

    final database = await this.database;
    try {
      await database.insert('custom_categories', {'name': normalizedName});
      return true;
    } on DatabaseException catch (error) {
      if (error.isUniqueConstraintError()) {
        return false;
      }
      rethrow;
    }
  }

  Future<int> deleteDocument(int id, String filePath) async {
    final database = await this.database;
    final deletedRows = await database.delete(
      'documents',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (filePath.isNotEmpty) {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    }

    return deletedRows;
  }
}
