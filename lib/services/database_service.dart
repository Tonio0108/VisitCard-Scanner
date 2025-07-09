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
      version: 1,
    );
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE VisitCard (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fullName TEXT,
        organisationName TEXT,
        email TEXT,
        profession TEXT,
        imageUrl TEXT DEFAULT 'assets/images/placeholder.webp'
      );
    ''');

    await db.execute('''
      CREATE TABLE Contact (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        visitCardId INTEGER,
        phoneNumber TEXT,
        FOREIGN KEY (visitCardId) REFERENCES VisitCard(id)
      );
    ''');

    await db.execute('''
      CREATE TABLE Website (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        visitCardId INTEGER,
        link TEXT,
        FOREIGN KEY (visitCardId) REFERENCES VisitCard(id)
      );
    ''');

    return db.execute('''
      CREATE TABLE SocialNetwork (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        visitCardId INTEGER,
        title TEXT,
        userName TEXT,
        FOREIGN KEY (visitCardId) REFERENCES VisitCard(id)
      );
    ''');
  }

  // Insert VisitCard with nested models
  Future<int> insertVisitCard(VisitCard card) async {
    final db = await database;

    // Only include base fields in the VisitCard table
    int visitCardId = await db.insert('VisitCard', {
      'fullName': card.fullName,
      'organisationName': card.organisationName,
      'email': card.email,
      'profession': card.profession,
      'imageUrl': card.imageUrl,
    });

    for (final contact in card.contacts) {
      await db.insert('Contact', {
        'visitCardId': visitCardId,
        'phoneNumber': contact.phoneNumber,
      });
    }

    for (final website in card.websites) {
      await db.insert('Website', {
        'visitCardId': visitCardId,
        'link': website.link,
      });
    }

    for (final sn in card.socialNetworks) {
      await db.insert('SocialNetwork', {
        'visitCardId': visitCardId,
        'title': sn.title,
        'userName': sn.userName,
      });
    }

    return visitCardId;
  }

  // Get all VisitCards with nested data
  Future<List<VisitCard>> getAllVisitCards() async {
    final db = await database;

    final visitCardMaps = await db.query(
      'VisitCard',
      orderBy: "fullName COLLATE NOCASE ASC",
    );
    List<VisitCard> cards = [];

    for (final map in visitCardMaps) {
      final id = map['id'] as int;

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
        orderBy: "title COLLATE NOCASE ASC", // Added ordering for consistency
      );

      cards.add(
        VisitCard(
          id: id,
          fullName: map['fullName'] as String,
          organisationName: map['organisationName'] as String,
          email: map['email'] as String,
          profession: map['profession'] as String,
          imageUrl: map['imageUrl'] as String?,
          contacts: contacts.map((c) => Contact.fromMap(c)).toList(),
          websites: websites.map((w) => Website.fromMap(w)).toList(),
          socialNetworks: socialNetworks
              .map((s) => SocialNetwork.fromMap(s))
              .toList(),
        ),
      );
    }

    return cards;
  }

  Future<int> updateVisitCard(VisitCard card) async {
    final db = await database;

    // Step 1: Update the main VisitCard row
    int count = await db.update(
      'VisitCard',
      {
        'fullName': card.fullName,
        'organisationName': card.organisationName,
        'email': card.email,
        'profession': card.profession,
        'imageUrl': card.imageUrl,
      },
      where: 'id = ?',
      whereArgs: [card.id],
    );

    // Step 2: Clear old child data
    await db.delete('Contact', where: 'visitCardId = ?', whereArgs: [card.id]);
    await db.delete('Website', where: 'visitCardId = ?', whereArgs: [card.id]);
    await db.delete(
      'SocialNetwork',
      where: 'visitCardId = ?',
      whereArgs: [card.id],
    );

    // Step 3: Insert new child data
    for (final contact in card.contacts) {
      await db.insert('Contact', {
        'visitCardId': card.id,
        'phoneNumber': contact.phoneNumber,
      });
    }

    for (final site in card.websites) {
      await db.insert('Website', {'visitCardId': card.id, 'link': site.link});
    }

    for (final social in card.socialNetworks) {
      await db.insert('SocialNetwork', {
        'visitCardId': card.id,
        'title': social.title,
        'userName': social.userName,
      });
    }

    return count;
  }

  // Delete VisitCard and related data
  Future<void> deleteVisitCard(int id) async {
    final db = await database;

    await db.delete('Contact', where: 'visitCardId = ?', whereArgs: [id]);
    await db.delete('Website', where: 'visitCardId = ?', whereArgs: [id]);
    await db.delete('SocialNetwork', where: 'visitCardId = ?', whereArgs: [id]);
    await db.delete('VisitCard', where: 'id = ?', whereArgs: [id]);
  }
}
