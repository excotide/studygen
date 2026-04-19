import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../generate/providers/quiz_provider.dart';
import '../../generate/models/quiz_model.dart';
import '../../../shared/widgets/botnav_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<QuizProvider>().fetchHistory(forceRefresh: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs    = Theme.of(context).colorScheme;
    final auth  = context.watch<AuthProvider>();
    final quiz  = context.watch<QuizProvider>();
    final name  = auth.user?.name.split(' ').first ?? 'kamu';
    final recent = quiz.history.take(3).toList();

    return MainScaffold(
      activeRoute: '/home',
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            // App bar
            SliverAppBar(
              backgroundColor: cs.surface,
              floating: true,
              pinned: false,
              elevation: 0,
              scrolledUnderElevation: 0,
              automaticallyImplyLeading: false,
              title: Text('StudyGen',
                  style: GoogleFonts.dmSerifDisplay(
                      fontSize: 22, color: cs.onSurface)),
              actions: [
                IconButton(
                  onPressed: () async {
                    await context.read<AuthProvider>().logout();
                    if (context.mounted) context.go('/login');
                  },
                  icon: Icon(Icons.logout_rounded,
                      size: 20, color: cs.onSurfaceVariant),
                ),
              ],
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Greeting
                  Text('Halo, $name 👋',
                      style: GoogleFonts.dmSerifDisplay(
                          fontSize: 24, color: cs.onSurface)),
                  const SizedBox(height: 4),
                  Text('Yuk mulai belajar hari ini.',
                      style: TextStyle(
                          fontSize: 14, color: cs.onSurfaceVariant)),
                  const SizedBox(height: 24),

                  // Stats row
                  Row(
                    children: [
                      _statCard(context, '${quiz.history.length}',
                          'Total rangkuman'),
                      const SizedBox(width: 10),
                      _statCard(context, _avgScore(quiz.history),
                          'Rata-rata'),
                      const SizedBox(width: 10),
                      _statCard(context,
                          '${_quizThisWeek(quiz.history)}', 'Minggu ini'),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Generate CTA
                  _generateCta(context),
                  const SizedBox(height: 28),

                  // Recent
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                        Text('Rangkuman terbaru',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: cs.onSurface)),
                      GestureDetector(
                        onTap: () => context.go('/history'),
                        child: Text('Lihat semua',
                            style: TextStyle(
                                fontSize: 13,
                                color: cs.onSurfaceVariant,
                                decoration: TextDecoration.underline,
                                decorationColor: cs.onSurfaceVariant)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (recent.isEmpty)
                    _emptyState(context)
                  else
                    ...recent.map((q) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _quizCard(context, q),
                        )),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(BuildContext context, String value, String label) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outline.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: GoogleFonts.dmSerifDisplay(
                    fontSize: 24, color: cs.onSurface)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 11, color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _generateCta(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => context.go('/generate'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cs.onSurface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    Text('Buat Rangkuman Baru',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: cs.surface)),
                  const SizedBox(height: 4),
                  Text('Upload PDF materi kuliah',
                      style: TextStyle(
                          fontSize: 13,
                          color: cs.surface.withValues(alpha: 0.6))),
                ],
              ),
            ),
            Icon(Icons.bolt_rounded, color: cs.surface, size: 28),
          ],
        ),
      ),
    );
  }

  Widget _quizCard(BuildContext context, QuizModel q) {
    final cs    = Theme.of(context).colorScheme;
    final score = q.lastScore;

    return GestureDetector(
      onTap: () => context.go('/summary', extra: q),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outline.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.description_outlined,
                  size: 18, color: cs.onSurfaceVariant),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(q.title,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: cs.onSurface),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text(
                      '${q.questions.length} soal · ${_timeAgo(q.createdAt)}',
                      style: TextStyle(
                          fontSize: 12, color: cs.onSurfaceVariant)),
                ],
              ),
            ),
            if (score != null) ...[
              const SizedBox(width: 8),
              _scoreBadge(context, score),
            ],
          ],
        ),
      ),
    );
  }

  Widget _scoreBadge(BuildContext context, int score) {
    final isGood = score >= 70;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isGood
            ? const Color(0xFFD8F3DC)
            : Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text('$score%',
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isGood
                  ? const Color(0xFF2D6A4F)
                  : Theme.of(context).colorScheme.onSurfaceVariant)),
    );
  }

  Widget _emptyState(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outline.withValues(alpha: 0.4)),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.quiz_outlined, size: 32, color: cs.onSurfaceVariant),
            const SizedBox(height: 10),
            Text('Belum ada rangkuman',
                style: TextStyle(
                    fontSize: 14, color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  String _avgScore(List<QuizModel> history) {
    final scored = history.where((q) => q.lastScore != null).toList();
    if (scored.isEmpty) return '-';
    final avg = scored.fold(0, (s, q) => s + q.lastScore!) ~/ scored.length;
    return '$avg%';
  }

  int _quizThisWeek(List<QuizModel> history) {
    final now   = DateTime.now();
    final start = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    return history.where((q) => q.createdAt.isAfter(start)).length;
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m lalu';
    if (diff.inHours < 24)   return '${diff.inHours}j lalu';
    if (diff.inDays == 1)    return 'Kemarin';
    if (diff.inDays < 7)     return '${diff.inDays}h lalu';
    return '${diff.inDays ~/ 7}mg lalu';
  }
}