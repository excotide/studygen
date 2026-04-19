import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../features/generate/providers/quiz_provider.dart';

class MainScaffold extends StatelessWidget {
  final Widget child;
  final String activeRoute;

  const MainScaffold({
    super.key,
    required this.child,
    required this.activeRoute,
  });

  int get _currentIndex {
    switch (activeRoute) {
      case '/home':     return 0;
      case '/generate': return 1;
      case '/history':  return 2;
      default:          return 0;
    }
  }

  void _onTap(BuildContext context, int index) {
    if (index == 0 || index == 2) {
      try {
        context.read<QuizProvider>().fetchHistory(forceRefresh: true);
      } catch (_) {}
    }
    switch (index) {
      case 0: context.go('/home');     break;
      case 1: context.go('/generate'); break;
      case 2: context.go('/history');  break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: cs.outline.withValues(alpha: 0.3))),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) => _onTap(context, i),
          backgroundColor: cs.surfaceContainerLow,
          selectedItemColor: cs.onSurface,
          unselectedItemColor: cs.onSurfaceVariant,
          selectedLabelStyle: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.w500),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.grid_view_rounded, size: 22),
              label: 'Beranda',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.add_circle_outline_rounded, size: 22),
              activeIcon: Icon(Icons.add_circle_rounded, size: 22),
              label: 'Rangkuman',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history_rounded, size: 22),
              label: 'Rangkuman',
            ),
          ],
        ),
      ),
    );
  }
}