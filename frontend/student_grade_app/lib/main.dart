import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'services/api_service.dart';
import 'providers/student_auth_provider.dart';
import 'providers/grade_provider.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/app_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GradeGuardianStudentApp());
}

class GradeGuardianStudentApp extends StatelessWidget {
  const GradeGuardianStudentApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final apiService = ApiService(baseUrl: ApiConfig.apiUrl);

    return MultiProvider(
      providers: [
        Provider<ApiService>.value(value: apiService),

        // Auth provider — restores session from secure storage on init
        ChangeNotifierProvider<StudentAuthProvider>(
          create: (_) => StudentAuthProvider(apiService),
        ),

        // Grade provider — syncs auth token via ProxyProvider
        ChangeNotifierProxyProvider<StudentAuthProvider, GradeProvider>(
          create: (_) => GradeProvider(apiService),
          update: (_, auth, previous) {
            apiService.authToken = auth.token;
            final provider = previous ?? GradeProvider(apiService);
            if (!auth.isAuthenticated) provider.clear();
            return provider;
          },
        ),
      ],
      child: MaterialApp(
        title: 'GradeGuardian — Student Portal',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const _AuthGate(),
      ),
    );
  }
}

/// Routes between login and app shell based on auth state.
class _AuthGate extends StatelessWidget {
  const _AuthGate({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<StudentAuthProvider>(
      builder: (context, auth, _) {
        switch (auth.authState) {
          case AuthState.unknown:
            // Session restore in progress — show splash
            return const Scaffold(
              backgroundColor: AppTheme.background,
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: AppTheme.primary),
                    SizedBox(height: 16),
                    Text('Restoring session…', style: AppTheme.bodyMedium),
                  ],
                ),
              ),
            );
          case AuthState.unauthenticated:
            return const LoginScreen();
          case AuthState.authenticated:
            return const AppShell();
        }
      },
    );
  }
}