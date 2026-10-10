import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';

import 'models/folder.dart';
import 'models/card_item.dart';

class DatabaseHelper {
  static const _databaseName = 'MyDatabase.db';
  static const _databaseVersion = 2;

  // Activity 08
  static const table = 'my_table';
  static const columnId = '_id';
  static const columnName = 'name';
  static const columnAge = 'age';

  late Database _db;

  Future<void> init() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();

    final path = join(documentsDirectory.path, _databaseName);

    _db = await openDatabase(
      path,
      version: _databaseVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $table (
        $columnId INTEGER PRIMARY KEY,
        $columnName TEXT NOT NULL,
        $columnAge INTEGER NOT NULL
      )
    ''');

    await _createFolderAndCardTables(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createFolderAndCardTables(db);
    }
  }

  Future<void> _createFolderAndCardTables(Database db) async {
    await db.execute('''
      CREATE TABLE folders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE cards (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        suit TEXT NOT NULL,
        notes TEXT NOT NULL DEFAULT '',
        image_ref TEXT,
        folder_id INTEGER NOT NULL,
        FOREIGN KEY (folder_id)
          REFERENCES folders(id)
          ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_cards_folder_id
      ON cards(folder_id)
    ''');
  }

  // Activity 08 methods

  Future<int> insert(Map<String, dynamic> row) async {
    return _db.insert(table, row);
  }

  Future<List<Map<String, dynamic>>> queryAllRows() async {
    return _db.query(table);
  }

  Future<int> queryRowCount() async {
    final results = await _db.rawQuery('SELECT COUNT(*) FROM $table');

    return Sqflite.firstIntValue(results) ?? 0;
  }

  Future<int> update(Map<String, dynamic> row) async {
    final id = row[columnId] as int;

    return _db.update(table, row, where: '$columnId = ?', whereArgs: [id]);
  }

  Future<int> delete(int id) async {
    return _db.delete(table, where: '$columnId = ?', whereArgs: [id]);
  }

  // Activity 09 folder methods

  Future<int> insertFolder(Folder folder) async {
    if (folder.name.trim().isEmpty) {
      throw ArgumentError('Folder name cannot be empty.');
    }

    return _db.insert('folders', folder.toMap());
  }

  Future<List<Folder>> getFoldersWithCounts() async {
    final rows = await _db.rawQuery('''
      SELECT
        folders.id,
        folders.name,
        folders.created_at,
        COUNT(cards.id) AS card_count
      FROM folders
      LEFT JOIN cards
        ON cards.folder_id = folders.id
      GROUP BY
        folders.id,
        folders.name,
        folders.created_at
      ORDER BY folders.name COLLATE NOCASE ASC
    ''');

    return rows.map((row) => Folder.fromMap(row)).toList();
  }

  Future<int> updateFolder(Folder folder) async {
    if (folder.id == null) {
      throw ArgumentError('Folder ID is required.');
    }

    if (folder.name.trim().isEmpty) {
      throw ArgumentError('Folder name cannot be empty.');
    }

    return _db.update(
      'folders',
      {'name': folder.name.trim()},
      where: 'id = ?',
      whereArgs: [folder.id],
    );
  }

  Future<int> deleteFolder(int id) async {
    return _db.delete('folders', where: 'id = ?', whereArgs: [id]);
  }

  // Activity 09 card methods

  static const supportedSuits = ['Hearts', 'Diamonds', 'Clubs', 'Spades'];

  Future<List<CardItem>> getCards(int folderId) async {
    final rows = await _db.query(
      'cards',
      where: 'folder_id = ?',
      whereArgs: [folderId],
      orderBy: 'title COLLATE NOCASE ASC',
    );

    return rows.map((row) => CardItem.fromMap(row)).toList();
  }

  void _validateCard(CardItem card) {
    if (card.title.trim().isEmpty) {
      throw ArgumentError('Card title cannot be empty.');
    }

    if (!supportedSuits.contains(card.suit)) {
      throw ArgumentError('Select a valid suit.');
    }

    if (card.folderId <= 0) {
      throw ArgumentError('Select a valid folder.');
    }
  }

  Future<int> insertCard(CardItem card) async {
    _validateCard(card);

    return _db.insert('cards', {
      'title': card.title.trim(),
      'suit': card.suit,
      'notes': card.notes,
      'image_ref': card.imageRef,
      'folder_id': card.folderId,
    });
  }

  Future<int> updateCard(CardItem card) async {
    if (card.id == null) {
      throw ArgumentError('Card ID is required.');
    }

    _validateCard(card);

    return _db.update(
      'cards',
      {
        'title': card.title.trim(),
        'suit': card.suit,
        'notes': card.notes,
        'image_ref': card.imageRef,
        'folder_id': card.folderId,
      },
      where: 'id = ?',
      whereArgs: [card.id],
    );
  }

  Future<int> deleteCard(int id) async {
    return _db.delete('cards', where: 'id = ?', whereArgs: [id]);
  }
}
