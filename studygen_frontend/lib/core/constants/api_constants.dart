import 'package:flutter/foundation.dart';

class ApiConstants {
  static const _apiBaseFromEnv = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_apiBaseFromEnv.isNotEmpty) {
      return _apiBaseFromEnv;
    }

    if (kIsWeb) {
      return 'http://localhost:8080/api';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:8080/api';
      default:
        return 'http://localhost:8080/api';
    }
  }

  static const String register = '/auth/register';
  static const String login    = '/auth/login';
  static const String logout   = '/auth/logout';
  static const String generate = '/quiz/generate';
  static String generateQuizFromSummary(int id) => '/quiz/$id/generate-quiz';
  static const String history  = '/quiz/history';
  static const String quizById = '/quiz';
  static const String score    = '/quiz';
}