import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';

/// Cache layer menggunakan Hive untuk data non-sensitif
/// (history quiz, dll)
class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  static const _historyBox  = 'quiz_history';
  static const _quizBox     = 'quiz_detail';
  static const _ttlBox      = 'cache_ttl';

  // TTL default: 5 menit
  static const _defaultTtl = Duration(minutes: 5);

  // ── Init (panggil di main.dart) ───────────────────────────────
  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(_historyBox);
    await Hive.openBox(_quizBox);
    await Hive.openBox(_ttlBox);
  }

  // ── History ───────────────────────────────────────────────────
  Future<void> saveHistory(List<Map<String, dynamic>> data) async {
    final box = Hive.box(_historyBox);
    await box.put('data', jsonEncode(data));
    await _setTtl('history');
  }

  List<Map<String, dynamic>>? getHistory() {
    if (_isExpired('history')) return null;
    final box  = Hive.box(_historyBox);
    final raw  = box.get('data');
    if (raw == null) return null;
    final list = jsonDecode(raw) as List;
    return list.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  // ── Quiz detail ───────────────────────────────────────────────
  Future<void> saveQuiz(int id, Map<String, dynamic> data) async {
    final box = Hive.box(_quizBox);
    await box.put('quiz_$id', jsonEncode(data));
    await _setTtl('quiz_$id');
  }

  Map<String, dynamic>? getQuiz(int id) {
    if (_isExpired('quiz_$id')) return null;
    final box = Hive.box(_quizBox);
    final raw = box.get('quiz_$id');
    if (raw == null) return null;
    return Map<String, dynamic>.from(jsonDecode(raw));
  }

  // ── Invalidate (hapus cache setelah generate / delete) ────────
  Future<void> invalidateHistory() async {
    final box = Hive.box(_historyBox);
    await box.clear();
    final ttl = Hive.box(_ttlBox);
    await ttl.delete('history');
  }

  Future<void> invalidateQuiz(int id) async {
    final box = Hive.box(_quizBox);
    await box.delete('quiz_$id');
    final ttl = Hive.box(_ttlBox);
    await ttl.delete('quiz_$id');
  }

  Future<void> clearAll() async {
    await Hive.box(_historyBox).clear();
    await Hive.box(_quizBox).clear();
    await Hive.box(_ttlBox).clear();
  }

  // ── TTL helpers ───────────────────────────────────────────────
  Future<void> _setTtl(String key,
      {Duration ttl = _defaultTtl}) async {
    final box     = Hive.box(_ttlBox);
    final expires = DateTime.now().add(ttl).millisecondsSinceEpoch;
    await box.put(key, expires);
  }

  bool _isExpired(String key) {
    final box     = Hive.box(_ttlBox);
    final expires = box.get(key) as int?;
    if (expires == null) return true;
    return DateTime.now().millisecondsSinceEpoch > expires;
  }
}