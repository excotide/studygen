import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'dart:typed_data';
import '../../../core/services/api_service.dart';
import '../../../core/services/cache_service.dart';
import '../../../core/constants/api_constants.dart';
import '../models/quiz_model.dart';

enum ExtractionMode { parser, mistral }

extension ExtractionModeExt on ExtractionMode {
  String get value {
    switch (this) {
      case ExtractionMode.parser:    return 'parser';
      case ExtractionMode.mistral:   return 'mistral';
    }
  }

  String get label {
    switch (this) {
      case ExtractionMode.parser:    return 'PDF Digital';
      case ExtractionMode.mistral:   return 'Mistral OCR';
    }
  }
}

class QuizProvider extends ChangeNotifier {
  List<QuizModel> _history  = [];
  QuizModel? _currentQuiz;
  bool _isLoading           = false;
  String? _error;

  List<QuizModel> get history  => _history;
  QuizModel? get currentQuiz   => _currentQuiz;
  bool get isLoading           => _isLoading;
  String? get error            => _error;

  String _dioToMessage(DioException e) {
    final backendMsg = e.response?.data is Map<String, dynamic>
        ? (e.response?.data['message']?.toString())
        : null;
    if (backendMsg != null && backendMsg.isNotEmpty) return backendMsg;

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Koneksi timeout. Coba lagi.';
      case DioExceptionType.connectionError:
        return 'Tidak bisa terhubung ke server. Pastikan backend aktif.';
      case DioExceptionType.badResponse:
        return 'Server mengembalikan error (${e.response?.statusCode ?? '-'})';
      case DioExceptionType.cancel:
        return 'Permintaan dibatalkan.';
      default:
        return e.message?.isNotEmpty == true
            ? e.message!
            : 'Gagal membuat rangkuman';
    }
  }

  // ── Generate ─────────────────────────────────────────────────
  Future<bool> generateQuiz({
    String? filePath,
    Uint8List? fileBytes,
    required String fileName,
    required ExtractionMode mode,
    required int numQuestions,
    required String summaryLength,
    required Function(String) onStep,
    Function(double)? onUploadProgress,
  }) async {
    _isLoading = true;
    _error     = null;
    notifyListeners();

    try {
      onStep('Menyiapkan file PDF...');

      final normalizedFileName =
          fileName.toLowerCase().endsWith('.pdf') ? fileName : '$fileName.pdf';

      MultipartFile pdfFile;
      if (fileBytes != null) {
        pdfFile = MultipartFile.fromBytes(fileBytes, filename: normalizedFileName);
      } else if (filePath != null && filePath.isNotEmpty) {
        pdfFile = await MultipartFile.fromFile(filePath, filename: normalizedFileName);
      } else {
        throw Exception('File PDF tidak valid');
      }

      final formData = FormData.fromMap({
        'pdf': pdfFile,
        'extraction_mode': mode.value,
        'num_questions':   numQuestions.toString(),
        'summary_length':  summaryLength,
      });

      onStep('Mengupload PDF...');

      final res = await ApiService().dio.post(
        ApiConstants.generate,
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          receiveTimeout: const Duration(seconds: 180),
        ),
        onSendProgress: (sent, total) {
          if (total <= 0) return;
          onUploadProgress?.call(sent / total);
        },
      );

      onStep(switch (mode) {
        ExtractionMode.parser    => 'Mengekstrak teks digital...',
        ExtractionMode.mistral   => 'Menjalankan Mistral OCR...',
      });
      onStep('Menyusun rangkuman...');
      _currentQuiz = QuizModel.fromJson(res.data['quiz']);

      // Update list lokal agar kartu quiz langsung muncul di beranda/riwayat.
      if (_currentQuiz != null) {
        _history.removeWhere((q) => q.id == _currentQuiz!.id);
        _history.insert(0, _currentQuiz!);
        await CacheService().saveHistory(_history.map((q) => {
          'id': q.id,
          'title': q.title,
          'summary': q.summary,
          'extraction_mode': q.extractionMode,
          'last_score': q.lastScore,
          'created_at': q.createdAt.toIso8601String(),
          'questions': q.questions
          .map((qq) => {
            'id': qq.id,
            'question': qq.question,
            'options': qq.options,
            'correct_answer': qq.correctAnswer,
              })
          .toList(),
        }).toList());
      }

      notifyListeners();
      return true;
    } on DioException catch (e) {
      _error = _dioToMessage(e);
      return false;
    } catch (e) {
      _error = 'Terjadi kesalahan: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<QuizModel?> generateQuizFromSummary(
    int quizId, {
    int numQuestions = 10,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final res = await ApiService().dio.post(
        ApiConstants.generateQuizFromSummary(quizId),
        data: {'num_questions': numQuestions},
      );

      final quiz = QuizModel.fromJson(res.data['quiz']);
      _currentQuiz = quiz;

      final idx = _history.indexWhere((q) => q.id == quiz.id);
      if (idx == -1) {
        _history.insert(0, quiz);
      } else {
        _history[idx] = quiz;
      }

      await CacheService().saveHistory(_history.map((q) => {
            'id': q.id,
            'title': q.title,
            'summary': q.summary,
            'extraction_mode': q.extractionMode,
            'last_score': q.lastScore,
            'created_at': q.createdAt.toIso8601String(),
            'questions': q.questions
                .map((qq) => {
                      'id': qq.id,
                      'question': qq.question,
                      'options': qq.options,
                      'correct_answer': qq.correctAnswer,
                    })
                .toList(),
          }).toList());

      notifyListeners();
      return quiz;
    } on DioException catch (e) {
      _error = _dioToMessage(e);
      notifyListeners();
      return null;
    } catch (e) {
      _error = 'Terjadi kesalahan: $e';
      notifyListeners();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── History dengan cache ──────────────────────────────────────
  Future<void> fetchHistory({bool forceRefresh = false}) async {
    // Cek cache dulu
    if (!forceRefresh) {
      final cached = CacheService().getHistory();
      if (cached != null) {
        _history = cached.map((q) => QuizModel.fromJson(q)).toList();
        notifyListeners();
        return;
      }
    }

    // Kalau cache miss / expired → fetch dari API
    try {
      final res = await ApiService().dio.get(ApiConstants.history);
      final raw = res.data['data'];
      if (raw is List) {
        final parsed = <QuizModel>[];
        for (final q in raw) {
          if (q is Map<String, dynamic>) {
            try {
              parsed.add(QuizModel.fromJson(q));
            } catch (_) {
              // Lewati item rusak tanpa menghilangkan seluruh history.
            }
          }
        }
        _history = parsed;
        // Simpan ke cache
        await CacheService().saveHistory(
          raw.map((q) => Map<String, dynamic>.from(q)).toList(),
        );
      } else {
        _history = [];
      }
      notifyListeners();
    } on DioException catch (_) {
      // Kalau network error, tampilkan data cache lama meski expired
      final stale = CacheService().getHistory();
      if (stale != null && _history.isEmpty) {
        _history = stale.map((q) => QuizModel.fromJson(q)).toList();
        notifyListeners();
      }
    } catch (_) {
      // Jangan hapus state history yang sudah tampil jika fetch baru gagal parse.
      if (_history.isEmpty) {
        final stale = CacheService().getHistory();
        if (stale != null) {
          _history = stale.map((q) => QuizModel.fromJson(q)).toList();
          notifyListeners();
        }
      }
    }
  }

  // ── Quiz by ID dengan cache ───────────────────────────────────
  Future<QuizModel?> fetchQuizById(int id) async {
    // Cek cache
    final cached = CacheService().getQuiz(id);
    if (cached != null) return QuizModel.fromJson(cached);

    // Fetch dari API
    try {
      final res  = await ApiService().dio.get('${ApiConstants.quizById}/$id');
      final data = res.data['quiz'] as Map<String, dynamic>;
      await CacheService().saveQuiz(id, data);
      return QuizModel.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  // ── Delete ────────────────────────────────────────────────────
  Future<bool> deleteQuiz(int id) async {
    try {
      await ApiService().dio.delete('${ApiConstants.quizById}/$id');
      _history.removeWhere((q) => q.id == id);
      await CacheService().invalidateHistory();
      await CacheService().invalidateQuiz(id);
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Save score ────────────────────────────────────────────────
  Future<void> saveScore(int quizId, int score) async {
    try {
      await ApiService().dio.patch(
        '${ApiConstants.score}/$quizId/score',
        data: {'score': score},
      );
      // Update local list
      final idx = _history.indexWhere((q) => q.id == quizId);
      if (idx != -1) {
        _history[idx] = QuizModel(
          id:             _history[idx].id,
          title:          _history[idx].title,
          summary:        _history[idx].summary,
          questions:      _history[idx].questions,
          createdAt:      _history[idx].createdAt,
          extractionMode: _history[idx].extractionMode,
          lastScore:      score,
        );
        notifyListeners();
      }
      // Invalidate cache
      await CacheService().invalidateHistory();
      await CacheService().invalidateQuiz(quizId);
    } catch (_) {}
  }
}