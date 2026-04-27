import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/api_service.dart';
import 'services/security_service.dart';
import 'providers/grade_provider.dart';
import 'screens/grades_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Perform security check before starting the app
  final securityService = SecurityService();
  final securityCheck = await securityService.performSecurityCheck();
  
  if (!securityCheck.passed) {
    runApp(SecurityBlockedApp(reason: securityCheck.reason!));
    return;
  }
  
  runApp(const GradeProtectionApp());
}

/// Main application widget
class GradeProtectionApp extends StatelessWidget {
  const GradeProtectionApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Initialize API service with your backend URL
    final apiService = ApiService(baseUrl: CertificatePinningConfig.apiUrl);
    
    return MultiProvider(
      providers: [
        // Provide API service
        Provider<ApiService>.value(value: apiService),
        
        // Provide Security service
        Provider<SecurityService>(create: (_) => SecurityService()),
        
        // Provide Grade state management
        ChangeNotifierProvider<GradeProvider>(
          create: (_) => GradeProvider(apiService),
        ),
      ],
      child: MaterialApp(
        title: 'GradeGuardian',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
          
          // Color scheme
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.light,
          ),
          
          // App bar theme
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            elevation: 0,
          ),
          
          // Card theme
          cardTheme: const CardThemeData(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
       ),
          
          // Input decoration theme
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
          ),
        ),
        
        // Dark theme
        darkTheme: ThemeData(
          brightness: Brightness.dark,
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.dark,
          ),
        ),
        
        // Home screen
        home: const GradesScreen(),
      ),
    );
  }
}

/// App shown when security check fails
class SecurityBlockedApp extends StatelessWidget {
  final String reason;
  
  const SecurityBlockedApp({Key? key, required this.reason}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.red.shade50,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.security,
                    size: 100,
                    color: Colors.red.shade700,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Security Check Failed',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade900,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    reason,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.red.shade700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade300),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: Colors.blue,
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Why is this happening?',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'The Grade Protection System requires a secure, '
                          'unmodified device to protect the integrity of '
                          'academic records. This app cannot run on rooted '
                          'or jailbroken devices.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
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
