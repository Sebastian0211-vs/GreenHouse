import 'package:flutter/foundation.dart';

import '/backend/sqlite/init.dart';

import 'package:sqflite/sqflite.dart';
export 'queries/read.dart';
export 'queries/update.dart';

class SQLiteManager {
  SQLiteManager._();

  static SQLiteManager? _instance;
  static SQLiteManager get instance => _instance ??= SQLiteManager._();

  static late Database _database;
  Database get database => _database;

  static Future initialize() async {
    if (kIsWeb) {
      return;
    }
    _database = await initializeDatabaseFromDbFile(
      '',
      '2vqf7_',
    );
  }

  /// START READ QUERY CALLS

  /// END READ QUERY CALLS

  /// START UPDATE QUERY CALLS

  /// END UPDATE QUERY CALLS
}
