import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/auth_provider.dart';
import '../../providers/theme_provider.dart';

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final username = authState.username ?? 'Usuario';  // Asume field username en AuthState
    final themeMode = ref.watch(themeProvider).themeMode;

    // Opcional: Auto-nav a dashboard después de 3s (descomenta)
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   Future.delayed(const Duration(seconds: 3), () {
    //     if (mounted) Navigator.pushReplacementNamed(context, '/dashboard');
    //   });
    // });

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: themeMode == ThemeMode.dark
                ? [Colors.grey.shade900, Colors.black]
                : [Colors.blue.shade50, Colors.white],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icono/Logo
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  ),
                  child: Icon(
                    Icons.picture_as_pdf,
                    size: 80,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 32),
                // Título
                Text(
                  '¡Bienvenido, $username!',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onBackground,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                // Subtítulo
                const Text(
                  'Descubre una forma simple de procesar tus PDFs.\nExtrae texto, imágenes y tablas con IA.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                // Quick Actions
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pushReplacementNamed(context, '/dashboard'),
                    icon: const Icon(Icons.dashboard),
                    label: const Text('Ir al Dashboard'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pushReplacementNamed(context, '/dashboard'),
                    icon: const Icon(Icons.upload),
                    label: const Text('Subir PDF Ahora'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Logout (opcional en welcome)
                TextButton(
                  onPressed: () async {
                    await ref.read(authProvider.notifier).logout();
                    Navigator.pushReplacementNamed(context, '/auth');
                  },
                  child: const Text('Cerrar Sesión'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
