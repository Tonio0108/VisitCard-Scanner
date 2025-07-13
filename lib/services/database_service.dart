import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import '../models/visit_card.dart';
import '../models/contact.dart';
import '../models/website.dart';
import '../models/social_network.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._();
  static Database? _database;

  DatabaseService._();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    return openDatabase(
      join(await getDatabasesPath(), 'visit_card.db'),
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      version: 3, // bump to 3 for new column
    );
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE VisitCard (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fullName TEXT NOT NULL,
        organisationName TEXT,
        email TEXT,
        profession TEXT,
        imageUrl TEXT DEFAULT 'assets/images/placeholder.webp',
        isSyncedToNative INTEGER DEFAULT 0,
        createdAt TEXT DEFAULT CURRENT_TIMESTAMP,
        updatedAt TEXT DEFAULT CURRENT_TIMESTAMP,
        UNIQUE(fullName, organisationName) ON CONFLICT REPLACE
      );
    ''');

    await db.execute('''
      CREATE TABLE Contact (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        visitCardId INTEGER,
        phoneNumber TEXT NOT NULL,
        FOREIGN KEY (visitCardId) REFERENCES VisitCard(id) ON DELETE CASCADE,
        UNIQUE(visitCardId, phoneNumber) ON CONFLICT IGNORE
      );
    ''');

    await db.execute('''
      CREATE TABLE Website (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        visitCardId INTEGER,
        link TEXT NOT NULL,
        FOREIGN KEY (visitCardId) REFERENCES VisitCard(id) ON DELETE CASCADE,
        UNIQUE(visitCardId, link) ON CONFLICT IGNORE
      );
    ''');

    await db.execute('''
      CREATE TABLE SocialNetwork (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        visitCardId INTEGER,
        title TEXT NOT NULL,
        userName TEXT NOT NULL,
        FOREIGN KEY (visitCardId) REFERENCES VisitCard(id) ON DELETE CASCADE,
        UNIQUE(visitCardId, title, userName) ON CONFLICT IGNORE
      );
    ''');

    // Indexes for performance
    await db.execute(
      'CREATE INDEX idx_visitcard_fullname ON VisitCard(fullName);',
    );
    await db.execute(
      'CREATE INDEX idx_contact_visitcardid ON Contact(visitCardId);',
    );
    await db.execute(
      'CREATE INDEX idx_website_visitcardid ON Website(visitCardId);',
    );
    await db.execute(
      'CREATE INDEX idx_socialnetwork_visitcardid ON SocialNetwork(visitCardId);',
    );
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 3) {
      await db.execute(
        'ALTER TABLE VisitCard ADD COLUMN isSyncedToNative INTEGER DEFAULT 0;',
      );
    }
  }

  Future<int> insertVisitCard(VisitCard card) async {
    final db = await database;
    return await db.transaction((txn) async {
      int visitCardId = await txn.insert('VisitCard', {
        'fullName': card.fullName,
        'organisationName': card.organisationName,
        'email': card.email,
        'profession': card.profession,
        'imageUrl': card.imageUrl,
        'isSyncedToNative': card.isSyncedToNative ? 1 : 0,
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      });

      for (final contact in card.contacts) {
        await txn.insert('Contact', {
          'visitCardId': visitCardId,
          'phoneNumber': contact.phoneNumber,
        });
      }

      for (final website in card.websites) {
        await txn.insert('Website', {
          'visitCardId': visitCardId,
          'link': website.link,
        });
      }

      for (final sn in card.socialNetworks) {
        await txn.insert('SocialNetwork', {
          'visitCardId': visitCardId,
          'title': sn.title,
          'userName': sn.userName,
        });
      }

      return visitCardId;
    });
  }

  Future<int> updateVisitCard(VisitCard card) async {
    final db = await database;
    return await db.transaction((txn) async {
      int count = await txn.update(
        'VisitCard',
        {
          'fullName': card.fullName,
          'organisationName': card.organisationName,
          'email': card.email,
          'profession': card.profession,
          'imageUrl': card.imageUrl,
          'isSyncedToNative': card.isSyncedToNative ? 1 : 0,
          'updatedAt': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [card.id],
      );

      // Clear old child data
      await txn.delete(
        'Contact',
        where: 'visitCardId = ?',
        whereArgs: [card.id],
      );
      await txn.delete(
        'Website',
        where: 'visitCardId = ?',
        whereArgs: [card.id],
      );
      await txn.delete(
        'SocialNetwork',
        where: 'visitCardId = ?',
        whereArgs: [card.id],
      );

      // Insert new child data
      for (final contact in card.contacts) {
        await txn.insert('Contact', {
          'visitCardId': card.id,
          'phoneNumber': contact.phoneNumber,
        });
      }

      for (final site in card.websites) {
        await txn.insert('Website', {
          'visitCardId': card.id,
          'link': site.link,
        });
      }

      for (final social in card.socialNetworks) {
        await txn.insert('SocialNetwork', {
          'visitCardId': card.id,
          'title': social.title,
          'userName': social.userName,
        });
      }

      return count;
    });
  }

  Future<VisitCard?> getVisitCardByName(String fullName) async {
    final db = await database;

    final result = await db.query(
      'VisitCard',
      where: 'LOWER(fullName) = LOWER(?)',
      whereArgs: [fullName],
      limit: 1,
    );

    if (result.isEmpty) return null;

    final map = result.first;
    final id = map['id'] as int;

    return await _buildVisitCardFromMap(map, id);
  }

  Future<VisitCard> _buildVisitCardFromMap(
    Map<String, dynamic> map,
    int id,
  ) async {
    final db = await database;

    final contacts = await db.query(
      'Contact',
      where: 'visitCardId = ?',
      whereArgs: [id],
    );
    final websites = await db.query(
      'Website',
      where: 'visitCardId = ?',
      whereArgs: [id],
    );
    final socialNetworks = await db.query(
      'SocialNetwork',
      where: 'visitCardId = ?',
      whereArgs: [id],
    );

    return VisitCard(
      id: id,
      fullName: map['fullName'] as String,
      organisationName: map['organisationName'] as String? ?? '',
      email: map['email'] as String? ?? '',
      profession: map['profession'] as String? ?? '',
      imageUrl: map['imageUrl'] as String?,
      contacts: contacts.map((c) => Contact.fromMap(c)).toList(),
      websites: websites.map((w) => Website.fromMap(w)).toList(),
      socialNetworks: socialNetworks
          .map((s) => SocialNetwork.fromMap(s))
          .toList(),
      isSyncedToNative: (map['isSyncedToNative'] ?? 0) == 1,
    );
  }

  Future<List<VisitCard>> getAllVisitCards() async {
    final db = await database;

    final visitCardMaps = await db.query(
      'VisitCard',
      orderBy: "fullName COLLATE NOCASE ASC",
    );
    List<VisitCard> cards = [];

    for (final map in visitCardMaps) {
      final id = map['id'] as int;
      final card = await _buildVisitCardFromMap(map, id);
      cards.add(card);
    }

    return cards;
  }

  /// Delete VisitCard and related data
  Future<void> deleteVisitCard(int id) async {
    final db = await database;

    await db.transaction((txn) async {
      await txn.delete('Contact', where: 'visitCardId = ?', whereArgs: [id]);
      await txn.delete('Website', where: 'visitCardId = ?', whereArgs: [id]);
      await txn.delete(
        'SocialNetwork',
        where: 'visitCardId = ?',
        whereArgs: [id],
      );
      await txn.delete('VisitCard', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<VisitCard?> getVisitCardById(int id) async {
    final db = await database;

    final result = await db.query(
      'VisitCard',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (result.isEmpty) return null;

    return await _buildVisitCardFromMap(result.first, id);
  }

  Future<VisitCard?> getLastInsertedVisitCard() async {
    final db = await database;

    final result = await db.query('VisitCard', orderBy: 'id DESC', limit: 1);

    if (result.isEmpty) return null;

    final map = result.first;
    final id = map['id'] as int;

    return await _buildVisitCardFromMap(map, id);
  }
}
