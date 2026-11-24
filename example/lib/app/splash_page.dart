import 'package:flutter/material.dart';

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.primary,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.widgets_rounded, size: 72, color: scheme.onPrimary),
            const SizedBox(height: 24),
            CircularProgressIndicator(color: scheme.onPrimary),
            const SizedBox(height: 16),
            Text(
              'Carregando configurações...',
              style: TextStyle(color: scheme.onPrimary),
            ),
          ],
        ),
      ),
    );
  }
}
