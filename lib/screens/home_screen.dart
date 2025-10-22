import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/pdf_uploader.dart';
import 'document_screen.dart';
import 'auth_screen.dart';  // Importa auth para redirect
import '../core/providers/auth_provider.dart';  // Provider para auth state

class HomeScreen extends ConsumerStatefulWidget {  // Cambia a Stateful para initState
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Check auth en init; si no logged, redirect (sin postFrame si no deps)
    final authState = ref.read(authProvider);
    if (!authState.isLoggedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const AuthScreen()),
          );
        }
      });
    }
  }

  Future<void> _logout() async {
    await ref.read(authProvider.notifier).logout();  // Fix: .notifier para method en AuthProvider
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AuthScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch auth para reactive changes (e.g., logout auto-redirect)
    ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Processor'),
        backgroundColor: Colors.transparent,  // Para gradient bleed
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFE3F2FD),  // blue.shade50
              Color(0xFFC5E1A5),  // indigo.shade100 (ajusté para mejor contraste)
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.picture_as_pdf,
                    size: 100,
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'PDF Processor',
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sube, procesa y traduce tus PDFs',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 48),
                  PDFUploader(
                    onSuccess: (documentId) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              DocumentScreen(documentId: documentId),
                        ),
                      );
                    },
                    onError: (error) {
                      // Maneja 401: Auto-logout si token invalid
                      if (error.toString().contains('401') || error.toString().contains('AuthException')) {
                        _logout();
                      } else {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $error')),
                          );
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
