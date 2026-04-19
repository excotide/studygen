import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../generate/models/quiz_model.dart';
import '../../generate/providers/quiz_provider.dart';

class SummaryScreen extends StatefulWidget {
  final QuizModel quiz;
  const SummaryScreen({super.key, required this.quiz});

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  late QuizModel _quiz;
  bool _isGeneratingQuiz = false;

  @override
  void initState() {
    super.initState();
    _quiz = widget.quiz;
  }

  Future<void> _startOrGenerateQuiz() async {
    if (_quiz.questions.isNotEmpty) {
      context.go('/quiz', extra: _quiz);
      return;
    }

    setState(() => _isGeneratingQuiz = true);
    final provider = context.read<QuizProvider>();
    final generated = await provider.generateQuizFromSummary(_quiz.id);

    if (!mounted) return;
    setState(() => _isGeneratingQuiz = false);

    if (generated == null || generated.questions.isEmpty) {
      final msg = provider.error ?? 'Gagal membuat quiz dari rangkuman.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    _quiz = generated;
    context.go('/quiz', extra: _quiz);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: cs.surface,
              floating: true,
              elevation: 0,
              scrolledUnderElevation: 0,
              automaticallyImplyLeading: false,
              title: Text(
                'Rangkuman Materi',
                style: GoogleFonts.dmSerifDisplay(
                  fontSize: 22,
                  color: cs.onSurface,
                ),
              ),
              actions: [
                IconButton(
                  onPressed: () => context.go('/home'),
                  icon: Icon(
                    Icons.home_rounded,
                    color: cs.onSurfaceVariant,
                    size: 20,
                  ),
                ),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: cs.outline.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _quiz.title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _quiz.summary,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: cs.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _quiz.questions.isEmpty
                        ? 'Rangkuman sudah siap. Quiz adalah fitur tambahan dan bisa dibuat kapan saja.'
                        : '${_quiz.questions.length} soal sudah siap. Kamu bisa kerjakan sekarang atau nanti.',
                    style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isGeneratingQuiz ? null : _startOrGenerateQuiz,
                      icon: _isGeneratingQuiz
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              _quiz.questions.isEmpty
                                  ? Icons.bolt_rounded
                                  : Icons.play_arrow_rounded,
                              size: 18,
                            ),
                      label: Text(_quiz.questions.isEmpty
                          ? 'Generate Quiz dari Rangkuman'
                          : 'Mulai Quiz'),
                      style: FilledButton.styleFrom(
                        backgroundColor: cs.onSurface,
                        foregroundColor: cs.surface,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
