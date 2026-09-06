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
      version: 1,
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
      whereClauses.add('(title LIKE ? OR category LIKE ?)');
      final searchPattern = '%${query.trim()}%';
      whereArguments.addAll([searchPattern, searchPattern]);
    }

    if (category.trim().isNotEmpty) {
      whereClauses.add('category = ?');
      whereArguments.add(category.trim());
    }

    return database.query(
      'documents',
      where: whereClauses.isEmpty ? null : whereClauses.join(' AND '),
      whereArgs: whereArguments.isEmpty ? null : whereArguments,
      orderBy: 'createdAt DESC',
    );
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