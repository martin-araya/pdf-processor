import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PageHeader extends StatelessWidget {
  final int index;
  final bool continuousView;
  final bool hasText;
  final bool hasImages;
  final bool showImages;
  final VoidCallback onCopy;
  final VoidCallback onToggleImages;

  const PageHeader({
    super.key,
    required this.index,
    required this.continuousView,
    required this.hasText,
    required this.hasImages,
    required this.showImages,
    required this.onCopy,
    required this.onToggleImages,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Badge página (solo no continuous)
        if (!continuousView)
          Align(
            alignment: Alignment.topRight,
            child: Container(
              key: ValueKey('badge_$index'),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'P$index',
                style: TextStyle(fontSize: 11, color: theme.colorScheme.primary),
              ),
            ),
          ),
        if (!continuousView) const SizedBox(height: 4),
        // Botones
        Row(
          children: [
            if (hasText)
              OutlinedButton.icon(
                key: const ValueKey('copy_btn'),
                onPressed: onCopy,
                icon: const Icon(Icons.copy, size: 14),
                label: const Text('Copiar', style: TextStyle(fontSize: 11)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
              ),
            const SizedBox(width: 6),
            if (hasImages)
              OutlinedButton.icon(
                key: ValueKey('toggle_imgs_$index'),
                onPressed: onToggleImages,
                icon: Icon(showImages ? Icons.visibility_off : Icons.visibility, size: 14),
                label: Text(showImages ? 'Ocultar' : 'Imgs', style: const TextStyle(fontSize: 11)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
