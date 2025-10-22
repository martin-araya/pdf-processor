import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';  // Para ConsumerStatefulWidget y ref
import '../core/providers/auth_provider.dart';  // Para notifier.login/register
import '../services/api_base.dart' show AuthException;
// Solo para AuthException (si needed en catch)

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLogin = true;  // Toggle login/register
  String? _error;
  bool _isLoading = false;  // Para button state
  bool _obscurePassword = true;  // Toggle visibility

  Future<void> _authenticate() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _error = null;  // Clear prev error
      _isLoading = true;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      final authNotifier = ref.read(authProvider.notifier);

      if (_isLogin) {
        // Login via notifier: Internal ApiService.login + save + validate + state true
        await authNotifier.login(email, password);
      } else {
        // Register via notifier: Internal ApiService.register + save userId + state true (sin token/validate)
        await authNotifier.register(email, password);
      }

      // Clear fields post-success
      _emailController.clear();
      _passwordController.clear();

      // Nav a Welcome (state ya true; Consumer en main nav auto, pero immediate aquí)
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/welcome');  // Actualizado a /welcome
      }
    } on AuthException catch (e) {
      // Specific: "Invalid credentials", "User already exists"
      setState(() => _error = e.message);
    } catch (e) {
      // Network/Dio/general
      final errorMsg = e.toString().contains('SocketException')
          ? 'Error de conexión. Verifica internet.'
          : (e.toString().contains('DioException') ? 'Error del servidor. Intenta de nuevo.' : e.toString());
      setState(() => _error = errorMsg);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isLogin ? 'Iniciar Sesión' : 'Registrarse'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 80, color: Colors.grey),
              const SizedBox(height: 32),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Email requerido';
                  if (!RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value!)) {
                    return 'Email inválido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Contraseña requerida';
                  final minLength = _isLogin ? 6 : 8;  // Login min 6, register min 8 (backend)
                  if (value!.length < minLength) {
                    return _isLogin
                        ? 'Mínimo 6 caracteres'
                        : 'Mínimo 8 caracteres para registro';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              if (_error != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _authenticate,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                      : Text(
                    _isLogin ? 'Iniciar Sesión' : 'Registrarse',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  setState(() {
                    _isLogin = !_isLogin;
                    _error = null;  // Clear error on toggle
                  });
                },
                child: Text(
                  _isLogin
                      ? '¿No tienes cuenta? Regístrate'
                      : '¿Ya tienes cuenta? Inicia sesión',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
