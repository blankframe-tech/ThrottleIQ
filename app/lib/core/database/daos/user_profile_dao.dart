import 'package:sqflite/sqflite.dart';

import '../database_helper.dart';

class UserProfileDao {
  Future<void> saveProfile(String uid, String displayName, {String? photoUrl}) async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now().toIso8601String();

    await db.insert(
      'user_profiles',
      {
        'uid': uid,
        'display_name': displayName,
        'photo_url': photoUrl,
        'created_at': now,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getProfile(String uid) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'user_profiles',
      where: 'uid = ?',
      whereArgs: [uid],
    );

    return rows.isEmpty ? null : rows.first;
  }

  Future<void> updateDisplayName(String uid, String displayName) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'user_profiles',
      {
        'display_name': displayName,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'uid = ?',
      whereArgs: [uid],
    );
  }

  Future<void> updatePhotoUrl(String uid, String photoUrl) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'user_profiles',
      {
        'photo_url': photoUrl,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'uid = ?',
      whereArgs: [uid],
    );
  }

  Future<void> deleteProfile(String uid) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete(
      'user_profiles',
      where: 'uid = ?',
      whereArgs: [uid],
    );
  }
}
