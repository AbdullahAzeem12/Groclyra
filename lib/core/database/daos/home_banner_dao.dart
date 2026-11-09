import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart' as sql;
import '../app_database.dart';
import '../realtime/sql_realtime_stream.dart';

/// Groclyra Marketing & Dynamic Banner CMS DAO
class HomeBannerDao {
  final Future<sql.Database?> Function() _getDb;
  final SqlRealtimeStreamManager _streamManager;

  HomeBannerDao(this._getDb, this._streamManager);

  /// Fetch all active banners ordered by displayOrder
  Future<List<Map<String, dynamic>>> getActiveBanners() async {
    final db = await _getDb();
    if (db != null) {
      return await db.query(
        'home_banners',
        where: 'isActive = 1',
        orderBy: 'displayOrder ASC',
      );
    }
    return await AppDatabase.instance.query(
      'home_banners',
      where: 'isActive = ?',
      whereArgs: [1],
      orderBy: 'displayOrder ASC',
    );
  }

  /// Fetch all banners for Admin CMS management
  Future<List<Map<String, dynamic>>> getAllBanners() async {
    final db = await _getDb();
    if (db != null) {
      return await db.query(
        'home_banners',
        orderBy: 'displayOrder ASC',
      );
    }
    return await AppDatabase.instance.query(
      'home_banners',
      orderBy: 'displayOrder ASC',
    );
  }

  /// Real-time stream of active promotional banners (for Customer Home)
  Stream<List<Map<String, dynamic>>> watchActiveBanners() {
    return _streamManager.createRealtimeQuery(
      watchTables: ['home_banners'],
      query: getActiveBanners,
    );
  }

  /// Real-time stream of all promotional banners (for Admin Console)
  Stream<List<Map<String, dynamic>>> watchAllBanners() {
    return _streamManager.createRealtimeQuery(
      watchTables: ['home_banners'],
      query: getAllBanners,
    );
  }

  /// Insert or update banner in SQLite and broadcast to real-time streams
  Future<void> saveBanner(Map<String, dynamic> banner) async {
    final db = await _getDb();
    if (db != null) {
      await db.insert(
        'home_banners',
        banner,
        conflictAlgorithm: sql.ConflictAlgorithm.replace,
      );
    } else {
      await AppDatabase.instance.insertOrReplace('home_banners', banner);
    }
    _streamManager.notifyTable('home_banners');
  }

  /// Toggle active status
  Future<void> toggleBannerStatus(String id, bool isActive) async {
    final db = await _getDb();
    if (db != null) {
      await db.update(
        'home_banners',
        {'isActive': isActive ? 1 : 0},
        where: 'id = ?',
        whereArgs: [id],
      );
    } else {
      await AppDatabase.instance.update(
        'home_banners',
        {'isActive': isActive ? 1 : 0},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
    _streamManager.notifyTable('home_banners');
  }

  /// Delete promotional banner
  Future<void> deleteBanner(String id) async {
    final db = await _getDb();
    if (db != null) {
      await db.delete(
        'home_banners',
        where: 'id = ?',
        whereArgs: [id],
      );
    } else {
      await AppDatabase.instance.delete(
        'home_banners',
        where: 'id = ?',
        whereArgs: [id],
      );
    }
    _streamManager.notifyTable('home_banners');
  }
}

final homeBannerDaoProvider = Provider<HomeBannerDao>((ref) {
  return AppDatabase.instance.homeBannerDao;
});

final activeHomeBannersStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(homeBannerDaoProvider).watchActiveBanners();
});

final allHomeBannersStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(homeBannerDaoProvider).watchAllBanners();
});
