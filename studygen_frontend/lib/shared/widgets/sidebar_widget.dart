import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../features/auth/providers/auth_provider.dart';

class SidebarWidget extends StatelessWidget {
  final String activeRoute;
  const SidebarWidget({super.key, required this.activeRoute});

  @override
  Widget build(BuildContext context) {
    final cs    = Theme.of(context).colorScheme;
    final auth  = context.watch<AuthProvider>();
    final name  = auth.user?.name ?? 'User';
    final email = auth.user?.email ?? '';
    final initials = name.isNotEmpty
        ? name.trim().split(' ').map((e) => e[0]).take(2).join().toUpperCase()
        : 'U';

    return Container(
      width: 220,
      color: cs.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
            child: Text('StudyGen',
                style: GoogleFonts.dmSerifDisplay(
                    fontSize: 20, color: cs.onSurface, letterSpacing: -.3)),
          ),
          _navItem(context, '/home', Icons.grid_view_rounded, 'Beranda'),
          _navItem(context, '/generate', Icons.add_rounded, 'Generate Baru'),
          _navItem(context, '/history', Icons.history_rounded, 'Riwayat'),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                border: Border.all(color: cs.outline.withValues(alpha: 0.6)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: cs.surfaceContainerHigh,
                    child: Text(initials,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: cs.onSurfaceVariant)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: cs.onSurface),
                            overflow: TextOverflow.ellipsis),
                        Text(email,
                            style: TextStyle(
                                fontSize: 11, color: cs.onSurfaceVariant),
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () async {
                      await context.read<AuthProvider>().logout();
                      if (context.mounted) context.go('/login');
                    },
                    child: Icon(Icons.logout_rounded,
                        size: 16, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _navItem(
      BuildContext context, String route, IconData icon, String label) {
    final cs       = Theme.of(context).colorScheme;
    final isActive = activeRoute == route;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
      child: InkWell(
        onTap: () => context.go(route),
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: isActive
                ? cs.surfaceContainerHigh
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(icon,
                  size: 16,
                  color: isActive
                      ? cs.onSurface
                      : cs.onSurfaceVariant),
              const SizedBox(width: 10),
              Text(label,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          isActive ? FontWeight.w500 : FontWeight.w400,
                      color: isActive
                          ? cs.onSurface
                          : cs.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}