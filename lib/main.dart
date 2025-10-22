import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/theme_provider.dart';
import 'core/providers/auth_provider.dart';  // Para auth state con loading
import 'screens/welcome_screen.dart';  // Nueva: Bienvenida post-auth
import 'screens/dashboard_screen.dart';  // Renombrado de home_screen
import 'screens/auth_screen.dart';  // Login/Register
import 'screens/document_screen.dart';  // Para view doc con args

void main() {
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider).themeMode;  // .themeMode del state

    return MaterialApp(
      title: 'PDF Processor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: themeMode,
      initialRoute: '/',
      routes: {
        '/': (context) => Consumer(
          builder: (context, ref, child) {
            final authState = ref.watch(authProvider);
            if (authState.isLoading) {
              return const SplashScreen();  // Loading mientras check auth
            }
            return authState.isLoggedIn
                ? const WelcomeScreen()  // Nueva: Bienvenida si loggedIn
                : const AuthScreen();
          },
        ),
        '/welcome': (context) => const WelcomeScreen(),  // Ruta explícita post-auth
        '/dashboard': (context) => const DashboardScreen(),  // Dashboard (lista docs)
        '/auth': (context) => const AuthScreen(),
        '/document': (context) {
          // Args para docId (de nav post-upload)
          final String docId = ModalRoute.of(context)?.settings.arguments as String? ?? '';
          return DocumentScreen(documentId: docId);  // Fallback empty si null
        },
      },
    );
  }
}

// SplashScreen simple (const-optimized)
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),  // Loader (const por default)
            SizedBox(height: 16),
            Text(
              'Loading...',
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
