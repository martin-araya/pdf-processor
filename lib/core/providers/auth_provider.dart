import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../services/api_base.dart' as api_base;  // Dio + AuthException + storage

// Estado auth (completo: loading, logged, user data, error)
class AuthState {
  final bool isLoading;
  final bool isLoggedIn;
  final String? userId;
  final String? username;  // Representa email (de Go response)
  final String? token;
  final String? error;

  const AuthState({
    this.isLoading = true,
    this.isLoggedIn = false,
    this.userId,
    this.username,
    this.token,
    this.error,
  });

  AuthState copyWith({
    bool? isLoading,
    bool? isLoggedIn,
    String? userId,
    String? username,
    String? token,
    String? error,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      token: token ?? this.token,
      error: error ?? this.error,
    );
  }
}

// StateNotifier para auth (usa ApiBase directo para simplicity)
class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState(isLoading: true)) {
    _initAuth();  // Auto-check token on init
  }

  // Init: Check stored token y validate
  Future<void> _initAuth() async {
    try {
      state = state.copyWith(isLoading: true);
      if (await api_base.ApiBase.isTokenSaved()) {
        final token = await api_base.ApiBase.getToken();
        if (token != null) {
          final valid = await _validateToken();  // Call internal
          if (valid != null) {
            final storedUsername = await api_base.ApiBase.getUsername();  // Email stored
            state = AuthState(
              isLoading: false,
              isLoggedIn: true,
              userId: valid['user_id']?.toString() ?? await api_base.ApiBase.getUserId(),
              username: storedUsername ?? valid['username']?.toString() ?? 'Usuario',  // Fix: username = email
              token: token,
            );
            debugPrint('✅ Auto-login success for ${state.username}');
            return;
          }
        }
      }
      // No valid token: Clear y logged out
      await api_base.ApiBase.clearAuth();
      state = const AuthState(isLoading: false, isLoggedIn: false);
      debugPrint('ℹ️ No valid token; requires login');
    } on api_base.AuthException catch (e) {
      debugPrint('❌ Init auth error: ${e.message}');
      await api_base.ApiBase.clearAuth();
      state = AuthState(
        isLoading: false,
        isLoggedIn: false,
        error: e.message,
      );
    } catch (e) {
      debugPrint('❌ Unexpected init error: $e');
      state = AuthState(
        isLoading: false,
        isLoggedIn: false,
        error: 'Error inicializando: $e',
      );
    }
  }

  // Internal: Validate token con /auth/validate (usa ApiBase Dio)
  Future<Map<String, dynamic>?> _validateToken() async {
    try {
      final dio = api_base.ApiBase.getAuthDio();
      final response = await dio.get<Map<String, dynamic>>('/auth/validate');
      if (response.statusCode == 200) {
        return response.data;  // {"valid":true, "user_id":1, "username":email}
      }
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await api_base.ApiBase.clearAuth();  // Clear invalid token
      }
      throw api_base.AuthException('Error validando: ${e.message}', statusCode: e.response?.statusCode);
    } catch (e) {
      throw api_base.AuthException('Conexión fallida: $e');
    }
  }

  // Login: POST /auth/login + store data (Fix: email vs username)
  Future<void> login(String email, String password) async {  // Fix: Param email
    try {
      state = state.copyWith(isLoading: true, error: null);
      final dio = api_base.ApiBase.getAuthDio();
      final response = await dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: {'email': email.trim(), 'password': password},  // Fix: 'email' en JSON
      );
      if (response.statusCode == 200) {
        final data = response.data!;
        final token = data['token'] as String?;
        final userId = data['user_id']?.toString() ?? '';
        final savedUsername = data['username']?.toString() ?? email.trim();  // Fix: username = email de response
        if (token != null && token.isNotEmpty) {
          await api_base.ApiBase.writeAuthData(token, userId, savedUsername);
          state = AuthState(
            isLoading: false,
            isLoggedIn: true,
            userId: userId,
            username: savedUsername,  // Email como username
            token: token,
          );
          debugPrint('✅ Login success for $savedUsername');
          return;
        }
        throw api_base.AuthException('Token no recibido del servidor');
      }
      throw api_base.AuthException('Login falló: ${response.statusCode}');
    } on DioException catch (e) {
      final msg = _getErrorMessage(e);
      state = state.copyWith(isLoading: false, error: msg);
      rethrow;  // Para screen catch y Snack
    } on api_base.AuthException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      rethrow;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Error inesperado: $e');
      rethrow;
    }
  }

  // Register: POST /auth/register + auto-login (Fix: email vs username)
  Future<void> register(String email, String password) async {  // Fix: Param email
    try {
      state = state.copyWith(isLoading: true, error: null);
      final dio = api_base.ApiBase.getAuthDio();
      final response = await dio.post<Map<String, dynamic>>(
        '/auth/register',
        data: {'email': email.trim(), 'password': password},  // Fix: 'email' en JSON
      );
      if (response.statusCode == 201) {
        final data = response.data!;
        final token = data['token'] as String?;
        final userId = data['user_id']?.toString() ?? '';
        final savedUsername = data['username']?.toString() ?? email.trim();  // Fix: username = email
        if (token != null && token.isNotEmpty) {
          await api_base.ApiBase.writeAuthData(token, userId, savedUsername);
          state = AuthState(
            isLoading: false,
            isLoggedIn: true,
            userId: userId,
            username: savedUsername,  // Email como username
            token: token,
          );
          debugPrint('✅ Register success for $savedUsername');
          return;
        }
        throw api_base.AuthException('Token no recibido del servidor');
      }
      throw api_base.AuthException('Registro falló: ${response.statusCode}');
    } on DioException catch (e) {
      final msg = _getErrorMessage(e);
      state = state.copyWith(isLoading: false, error: msg);
      rethrow;
    } on api_base.AuthException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      rethrow;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Error inesperado: $e');
      rethrow;
    }
  }

  // Logout: Clear storage y state
  Future<void> logout() async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      await api_base.ApiBase.clearAuth();
      state = const AuthState(isLoading: false, isLoggedIn: false);
      debugPrint('🔓 Logout success');
    } on api_base.AuthException catch (e) {
      debugPrint('❌ Logout error: ${e.message}');
      state = const AuthState(isLoading: false, isLoggedIn: false);  // Force clear anyway
    } catch (e) {
      debugPrint('❌ Unexpected logout error: $e');
      state = AuthState(isLoading: false, isLoggedIn: false, error: e.toString());
    }
  }

  // Refresh: Usa ApiBase.refreshToken
  Future<void> refresh() async {
    final token = state.token;
    if (token == null) {
      await logout();
      return;
    }
    try {
      state = state.copyWith(isLoading: true, error: null);
      final newToken = await api_base.ApiBase.refreshToken(token);
      if (newToken != null) {
        final userId = state.userId ?? '';
        final username = state.username ?? '';
        await api_base.ApiBase.writeAuthData(newToken, userId, username);
        state = state.copyWith(token: newToken, isLoading: false);
        debugPrint('✅ Token refreshed for ${state.username}');
      } else {
        await logout();  // Fail → logout
      }
    } on api_base.AuthException catch (e) {
      debugPrint('❌ Refresh error: ${e.message}');
      await logout();
    } catch (e) {
      debugPrint('❌ Refresh unexpected error: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
      await logout();
    }
  }

  // Clear error (para UI: dismiss snack)
  void clearError() {
    state = state.copyWith(error: null);
  }

  // Helper: Msg para Dio errors (basado en statusCode; Fix: Match Go msgs)
  String _getErrorMessage(DioException e) {
    final code = e.response?.statusCode;
    switch (code) {
      case 404:
        return 'Servidor no encontrado (verifica puerto 9001)';
      case 401:
        return 'Usuario o contraseña inválidos';  // Fix: Match Go 401
      case 409:
        return 'Usuario ya existe';  // Fix: Match Go conflict
      case 400:
        return 'Datos inválidos (password mínimo 6 caracteres)';  // Fix: Match Go binding/min len
      case 500:
        return 'Error en servidor auth. Intenta más tarde';  // Fix: Match Go
      default:
        return 'Error de red: ${e.message}';
    }
  }
}

// Provider principal (global, no autoDispose)
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
