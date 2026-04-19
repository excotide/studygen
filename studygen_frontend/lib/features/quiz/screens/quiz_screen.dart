import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../generate/models/quiz_model.dart';

class QuizScreen extends StatefulWidget {
  final QuizModel quiz;
  const QuizScreen({super.key, required this.quiz});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int _currentIndex = 0;
  final Map<int, int> _answers = {};
  bool _answered = false;

  QuestionModel get _currentQ =>
      widget.quiz.questions[_currentIndex];

  void _answer(int optionIndex) {
    if (_answered) return;
    setState(() {
      _answered = true;
      _answers[_currentIndex] = optionIndex;
    });
  }

  void _next() {
    if (_currentIndex < widget.quiz.questions.length - 1) {
      setState(() {
        _currentIndex++;
        _answered = false;
      });
    } else {
      // Go to result
      final correct = _answers.entries
          .where((e) =>
              widget.quiz.questions[e.key].correctAnswer == e.value)
          .length;
      final score =
          (correct / widget.quiz.questions.length * 100).round();
      context.go('/result', extra: {
        'quiz': widget.quiz,
        'score': score,
        'correct': correct,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs       = Theme.of(context).colorScheme;
    final total    = widget.quiz.questions.length;
    final progress = (_currentIndex + 1) / total;
    final isLast   = _currentIndex == total - 1;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Column(
          children: [
          const SizedBox(height: 8),
          // Top bar
          Container(
            padding: const EdgeInsets.fromLTRB(36, 24, 36, 16),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              border: Border(bottom: BorderSide(color: cs.outline.withValues(alpha: 0.4))),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.quiz.title,
                            style: TextStyle(
                                fontSize: 12,
                                color: cs.onSurfaceVariant,
                                letterSpacing: .04),
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                    Text('${_currentIndex + 1} / $total',
                        style: TextStyle(
                            fontSize: 13, color: cs.onSurfaceVariant)),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 3,
                    backgroundColor: cs.outline.withValues(alpha: 0.3),
                    color: cs.onSurface,
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(36, 32, 36, 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SOAL ${_currentIndex + 1} DARI $total',
                      style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurfaceVariant,
                          letterSpacing: .08,
                          fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 10),
                    Text(_currentQ.question,
                        style: GoogleFonts.dmSerifDisplay(
                            fontSize: 20,
                            color: cs.onSurface,
                            height: 1.4)),
                    const SizedBox(height: 24),

                    // Options
                    ...List.generate(
                      _currentQ.options.length,
                      (i) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _buildOption(context, i),
                      ),
                    ),

                    // Next button
                    if (_answered) ...[
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _next,
                        style: FilledButton.styleFrom(
                          backgroundColor: cs.onSurface,
                          foregroundColor: cs.surface,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 28, vertical: 13),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text(isLast ? 'Lihat Hasil' : 'Soal Berikutnya →'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          ],
        ),
      ),
    );
  }

  Widget _buildOption(BuildContext context, int index) {
    final cs      = Theme.of(context).colorScheme;
    final correct = _currentQ.correctAnswer;
    final chosen  = _answers[_currentIndex];
    final letters = ['A', 'B', 'C', 'D'];

    Color borderColor = cs.outline.withValues(alpha: 0.5);
    Color bgColor     = cs.surfaceContainerLow;
    Color textColor   = cs.onSurface;
    Color letterBg    = cs.surfaceContainerHigh;
    Color letterColor = cs.onSurfaceVariant;
    double opacity    = 1.0;

    if (_answered) {
      if (index == correct) {
        borderColor = const Color(0xFF2D6A4F);
        bgColor     = const Color(0xFFD8F3DC);
        textColor   = const Color(0xFF1B4332);
        letterBg    = const Color(0xFF2D6A4F);
        letterColor = Colors.white;
      } else if (index == chosen && index != correct) {
        borderColor = const Color(0xFFC1121F);
        bgColor     = const Color(0xFFFFE5E5);
        textColor   = const Color(0xFF7B1313);
        letterBg    = const Color(0xFFC1121F);
        letterColor = Colors.white;
      } else {
        opacity = 0.45;
      }
    }

    return Opacity(
      opacity: opacity,
      child: GestureDetector(
        onTap: () => _answer(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor, width: 1.5),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: _answered && (index == correct || index == chosen)
                      ? letterBg
                      : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _answered && (index == correct || index == chosen)
                        ? letterBg
                        : cs.outline.withValues(alpha: 0.6),
                  ),
                ),
                child: Center(
                  child: Text(letters[index],
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: _answered &&
                                  (index == correct || index == chosen)
                              ? letterColor
                              : cs.onSurfaceVariant)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(_currentQ.options[index],
                    style: TextStyle(fontSize: 14, color: textColor)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}