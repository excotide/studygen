import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../generate/providers/quiz_provider.dart';
import '../../generate/models/quiz_model.dart';

class ResultScreen extends StatefulWidget {
  final QuizModel quiz;
  final int score;
  final int correct;

  const ResultScreen({
    super.key,
    required this.quiz,
    required this.score,
    required this.correct,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<QuizProvider>().saveScore(widget.quiz.id, widget.score);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs    = Theme.of(context).colorScheme;
    final wrong = widget.quiz.questions.length - widget.correct;

    return Scaffold(
      backgroundColor: cs.surface,
      body: Column(
        children: [
          // Top bar
          Container(
            padding: const EdgeInsets.fromLTRB(36, 20, 36, 16),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              border: Border(
              bottom: BorderSide(color: cs.outline.withValues(alpha: 0.4))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Hasil Quiz',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: cs.onSurface)),
                OutlinedButton(
                  onPressed: () => context.go('/home'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    side: BorderSide(color: cs.outline),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('Kembali ke Beranda',
                      style: TextStyle(
                          fontSize: 13, color: cs.onSurfaceVariant)),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(36, 48, 36, 48),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${widget.score}%',
                        style: GoogleFonts.dmSerifDisplay(
                            fontSize: 64,
                            color: cs.onSurface,
                            letterSpacing: -1)),
                    const SizedBox(height: 6),
                    Text(widget.quiz.title,
                        style: TextStyle(
                            fontSize: 14, color: cs.onSurfaceVariant)),
                    const SizedBox(height: 32),

                    // Stats
                    Row(
                      children: [
                        _statBox(context, '${widget.correct}', 'Benar',
                            const Color(0xFF2D6A4F), const Color(0xFFD8F3DC)),
                        const SizedBox(width: 12),
                        _statBox(context, '$wrong', 'Salah',
                            const Color(0xFFC1121F), const Color(0xFFFFE5E5)),
                        const SizedBox(width: 12),
                        _statBox(context, '${widget.quiz.questions.length}',
                            'Total soal', cs.onSurfaceVariant,
                            cs.surfaceContainerLow),
                      ],
                    ),
                    const SizedBox(height: 36),

                    // Feedback
                    _buildFeedback(context, widget.score),
                    const SizedBox(height: 32),

                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            onPressed: () =>
                              context.go('/quiz', extra: widget.quiz),
                            style: FilledButton.styleFrom(
                              backgroundColor: cs.onSurface,
                              foregroundColor: cs.surface,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('Coba Lagi'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => context.go('/generate'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              side: BorderSide(color: cs.outline),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            child: Text('Quiz Baru',
                                style:
                                    TextStyle(color: cs.onSurface)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statBox(BuildContext context, String value, String label,
      Color textColor, Color bgColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: textColor.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(value,
                style: GoogleFonts.dmSerifDisplay(
                    fontSize: 24, color: textColor)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.8))),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedback(BuildContext context, int score) {
    final cs = Theme.of(context).colorScheme;
    String emoji, title, desc;

    if (score >= 90) {
      emoji = '🎉';
      title = 'Luar biasa!';
      desc  = 'Pemahaman kamu sangat baik. Pertahankan!';
    } else if (score >= 70) {
      emoji = '👍';
      title = 'Bagus!';
      desc  = 'Kamu sudah menguasai sebagian besar materi.';
    } else if (score >= 50) {
      emoji = '📚';
      title = 'Cukup baik';
      desc  = 'Ada beberapa bagian yang perlu dipelajari ulang.';
    } else {
      emoji = '💪';
      title = 'Terus semangat!';
      desc  = 'Coba baca ulang rangkuman dan kerjakan lagi.';
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurface)),
              Text(desc,
                  style:
                      TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
            ],
          ),
        ],
      ),
    );
  }
}