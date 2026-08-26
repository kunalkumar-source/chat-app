import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import '../../../../core/database_helper.dart';
import '../models/reel_model.dart';

abstract class IReelsRepository {
  Future<List<ReelModel>> getReels({int page = 1, int limit = 10});
}

class ReelsRepositoryImpl implements IReelsRepository {
  final Dio _dio = Dio();
  final String _baseUrl = 'https://instagram-0q68.onrender.com';
  final DatabaseHelper _dbHelper = DatabaseHelper();

  @override
  Future<List<ReelModel>> getReels({int page = 1, int limit = 10}) async {
    final apiUrl = '$_baseUrl/api/v1/reels-Public?page=$page&limit=$limit';
    try {
      final response = await _dio.get(apiUrl);
      if (response.statusCode == 200) {
        final List<dynamic> rawData = response.data['data'];
        final reels =
            rawData.map((json) => ReelModel.fromJson(json, _baseUrl)).toList();

        // Cache for offline use
        await _cacheReels(reels);

        // Step 5: Pre-fetch first 3 videos for seamless scrolling
        _prefetchVideos(reels.take(3).toList());

        return reels;
      }
    } catch (e) {
      debugPrint('Reels Repository: Network error, loading from cache. $e');
    }

    // Fallback to offline cache
    final cachedReels = await _getCachedReels();

    // Pre-fetch cached videos if any
    if (cachedReels.isNotEmpty) {
      _prefetchVideos(cachedReels.take(3).toList());
    }

    return cachedReels;
  }

  void _prefetchVideos(List<ReelModel> reels) {
    for (var reel in reels) {
      // Triggering the cache manager in the background
      DefaultCacheManager().getSingleFile(reel.videoUrl).catchError((e) {
        debugPrint('Prefetch failed: $e');
        throw e;
      });
    }
  }

  Future<void> _cacheReels(List<ReelModel> reels) async {
    final db = await _dbHelper.database;
    final batch = db.batch();
    // For pagination, we might not want to delete everything if it's a new page
    // but for simple offline-first we can replace the cache or append.
    // For now, let's replace to keep it simple as per original logic,
    // but in a real app we'd likely append or use a specific cache strategy.
    for (var reel in reels) {
      batch.insert('reels_cache', reel.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<ReelModel>> _getCachedReels() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('reels_cache');
    return maps.map((map) => ReelModel.fromMap(map)).toList();
  }
}
