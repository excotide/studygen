import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../generate/providers/quiz_provider.dart';
import '../../generate/models/quiz_model.dart';
import '../../../shared/widgets/botnav_widget.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<QuizProvider>().fetchHistory(forceRefresh: true);
    });
  }

  Future<void> _confirmDelete(BuildContext context, QuizModel q) async {
    final provider = context.read<QuizProvider>();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Hapus rangkuman?',
                style: GoogleFonts.dmSerifDisplay(fontSize: 20)),
            const SizedBox(height: 8),
            Text('"${q.title}" akan dihapus permanen.',
                style: TextStyle(
                    fontSize: 14,
                    color:
                        Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      side: BorderSide(
                          color: Theme.of(context).colorScheme.outline),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Batal'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: FilledButton.styleFrom(
                      backgroundColor:
                          Theme.of(context).colorScheme.error,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Hapus'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (ok != true || !mounted) return;
    await provider.deleteQuiz(q.id);
  }

  @override
  Widget build(BuildContext context) {
    final cs   = Theme.of(context).colorScheme;
    final quiz = context.watch<QuizProvider>();

    return MainScaffold(
      activeRoute: '/history',
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: cs.surface,
              floating: true,
              elevation: 0,
              scrolledUnderElevation: 0,
              automaticallyImplyLeading: false,
                title: Text('Riwayat Rangkuman',
                  style: GoogleFonts.dmSerifDisplay(
                      fontSize: 22, color: cs.onSurface)),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
              sliver: quiz.history.isEmpty
                  ? SliverFillRemaining(child: _emptyState(context))
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _historyItem(context, quiz.history[i]),
                        ),
                        childCount: quiz.history.length,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _historyItem(BuildContext context, QuizModel q) {
    final cs    = Theme.of(context).colorScheme;
    final score = q.lastScore;

    return Dismissible(
      key: Key('quiz-${q.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: cs.error,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline_rounded,
            color: Colors.white, size: 22),
      ),
      confirmDismiss: (_) async {
        await _confirmDelete(context, q);
        return false; // deleteQuiz sudah handle list update
      },
      child: GestureDetector(
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
                width: 42,
                height: 42,
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
                        '${q.questions.length} soal · ${q.extractionMode} · ${_timeAgo(q.createdAt)}',
                        style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
              if (score != null) ...[
                const SizedBox(width: 8),
                _scoreBadge(context, score),
              ],
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded,
                  size: 18, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  Widget _scoreBadge(BuildContext context, int score) {
    final isGood = score >= 70;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isGood
            ? const Color(0xFFD8F3DC)
            : Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text('$score%',
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: isGood
                  ? const Color(0xFF2D6A4F)
                  : Theme.of(context).colorScheme.onSurfaceVariant)),
    );
  }

  Widget _emptyState(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_rounded, size: 48, color: cs.onSurfaceVariant),
          const SizedBox(height: 16),
          Text('Belum ada riwayat',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface)),
          const SizedBox(height: 6),
            Text('Rangkuman yang dibuat akan muncul di sini.',
              style:
                  TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => context.go('/generate'),
            style: FilledButton.styleFrom(
              backgroundColor: cs.onSurface,
              foregroundColor: cs.surface,
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Buat Rangkuman Pertama'),
          ),
        ],
      ),
    );
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