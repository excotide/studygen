import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../features/generate/providers/quiz_provider.dart';

class MainScaffold extends StatefulWidget {
  final Widget child;
  final String activeRoute;

  const MainScaffold({
    super.key,
    required this.child,
    required this.activeRoute,
  });

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  static int? _lastTabIndex;
  late final Offset _beginOffset;

  int _routeToIndex(String route) {
    switch (route) {
      case '/home':
        return 0;
      case '/generate':
        return 1;
      case '/history':
        return 2;
      default:
        return 0;
    }
  }

  String _indexToRoute(int index) {
    switch (index) {
      case 0:
        return '/home';
      case 1:
        return '/generate';
      case 2:
        return '/history';
      default:
        return '/home';
    }
  }

  @override
  void initState() {
    super.initState();
    final current = _routeToIndex(widget.activeRoute);
    final previous = _lastTabIndex;

    if (previous == null || previous == current) {
      _beginOffset = Offset.zero;
    } else {
      // Pindah ke tab kiri => konten bergerak ke kanan. Pindah ke kanan => ke kiri.
      _beginOffset = current < previous
          ? const Offset(-0.16, 0)
          : const Offset(0.16, 0);
    }

    _lastTabIndex = current;
  }

  int get _currentIndex {
    return _routeToIndex(widget.activeRoute);
  }

  void _onTap(BuildContext context, int index) {
    if (index == _currentIndex) return;

    if (index == 0 || index == 2) {
      try {
        context.read<QuizProvider>().fetchHistory(forceRefresh: true);
      } catch (_) {}
    }

    context.go(_indexToRoute(index));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: ClipRect(
        child: TweenAnimationBuilder<Offset>(
          tween: Tween<Offset>(begin: _beginOffset, end: Offset.zero),
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          child: widget.child,
          builder: (context, offset, child) {
            return Transform.translate(
              offset: Offset(offset.dx * 120, 0),
              child: Opacity(
                opacity: 1 - (offset.dx.abs() * 0.35),
                child: child,
              ),
            );
          },
        ),
      ),
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