class QuizModel {
  final int id;
  final String title;
  final String summary;
  final String extractionMode;
  final List<QuestionModel> questions;
  final DateTime createdAt;
  final int? lastScore;

  QuizModel({
    required this.id,
    required this.title,
    required this.summary,
    this.extractionMode = 'parser',
    required this.questions,
    required this.createdAt,
    this.lastScore,
  });

  factory QuizModel.fromJson(Map<String, dynamic> json) => QuizModel(
      id: json['id'] is String
        ? int.tryParse(json['id']) ?? 0
        : (json['id'] as num?)?.toInt() ?? 0,
        title: (json['title'] ?? '').toString(),
        summary: (json['summary'] ?? '').toString(),
      extractionMode: (json['extraction_mode'] ?? 'parser').toString(),
      questions: ((json['questions'] as List?) ?? const [])
        .map((q) => QuestionModel.fromJson(q as Map<String, dynamic>))
            .toList(),
      createdAt: json['created_at'] != null
        ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
        : DateTime.now(),
        lastScore: json['last_score'],
      );
}

class QuestionModel {
  final int id;
  final String question;
  final List<String> options;
  final int correctAnswer;

  QuestionModel({
    required this.id,
    required this.question,
    required this.options,
    required this.correctAnswer,
  });

  factory QuestionModel.fromJson(Map<String, dynamic> json) => QuestionModel(
      id: json['id'] is String
      ? int.tryParse(json['id']) ?? 0
      : (json['id'] as num?)?.toInt() ?? 0,
        question: (json['question'] ?? '').toString(),
        options: List<String>.from((json['options'] as List?) ?? const []),
        correctAnswer: json['correct_answer'] is num
            ? (json['correct_answer'] as num).toInt()
            : int.tryParse('${json['correct_answer']}') ?? 0,
      );
}