import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'my_secure_app.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await _createTables(db);
      },
    );
  }

  Future<void> _createTables(Database db) async {
    // 1. Chat Users Table
    await db.execute(
        'CREATE TABLE IF NOT EXISTS chat_users(id TEXT PRIMARY KEY, name TEXT, avatarUrl TEXT, lastSeen INTEGER, isOnline INTEGER)');

    // 2. Conversations Table
    await db.execute(
        'CREATE TABLE IF NOT EXISTS conversations(id TEXT PRIMARY KEY, participantId TEXT, lastMessageText TEXT, lastMessageAt INTEGER, lastMessageSenderId TEXT, unreadCount INTEGER DEFAULT 0)');

    // 3. Messages Table
    await db.execute(
        'CREATE TABLE IF NOT EXISTS messages(localId INTEGER PRIMARY KEY AUTOINCREMENT, clientMessageId TEXT UNIQUE, serverMessageId TEXT UNIQUE, conversationId TEXT, senderId TEXT, text TEXT, createdAt INTEGER, serverCreatedAt INTEGER, serverSequence INTEGER, syncStatus TEXT, deliveryStatus TEXT, type TEXT, replyToMessageId TEXT, isEdited INTEGER DEFAULT 0, editedAt INTEGER, isDeleted INTEGER DEFAULT 0, deletedAt INTEGER)');

    // 4. Message Outbox Queue Table
    await db.execute(
        'CREATE TABLE IF NOT EXISTS message_outbox(id INTEGER PRIMARY KEY AUTOINCREMENT, operation TEXT, entityId TEXT, payload TEXT, status TEXT, retryCount INTEGER DEFAULT 0, nextRetryAt INTEGER, lastError TEXT, createdAt INTEGER)');
  }
}
