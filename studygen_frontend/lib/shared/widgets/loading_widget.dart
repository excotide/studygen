import 'package:flutter/material.dart';

class LoadingWidget extends StatelessWidget {
  final String message;
  final double? progress;

  const LoadingWidget({
    super.key,
    this.message = 'Memuat...',
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: cs.onSurface,
                value: progress,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            if (progress != null) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 3,
                  backgroundColor: cs.outline.withValues(alpha: 0.3),
                  color: cs.onSurface,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}