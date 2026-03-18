import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:workmanager/workmanager.dart';

import 'config/api_config.dart';
import 'models/schema.dart';
import 'providers/app_providers.dart';
import 'screens/conflict_resolution_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/mastery_dashboard_screen.dart';
import 'screens/observation_capture_screen.dart';
import 'screens/rubric_assessment_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/student_detail_screen.dart';
import 'screens/student_list_screen.dart';
import 'services/auth_service.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    return true;
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final dir = await getApplicationDocumentsDirectory();
  final isar = await Isar.open(
    allSchemas,
    directory: dir.path,
  );

  await Workmanager().initialize(
    callbackDispatcher,
    isInDebugMode: false,
  );
  await Workmanager().registerPeriodicTask(
    'readlepress-sync',
    'syncPendingData',
    frequency: const Duration(minutes: 15),
    constraints: Constraints(
      networkType: NetworkType.connected,
    ),
  );

  final apiConfig = ApiConfig(
    baseUrl: 'http://localhost:3000',
  );
  final dio = _createDio();
  final authService = AuthService(
    dio: dio,
    apiConfig: apiConfig,
  );
  authService.configureAuthInterceptor();

  runApp(
    ProviderScope(
      overrides: [
        isarProvider.overrideWithValue(isar),
        apiConfigProvider.overrideWithValue(apiConfig),
        dioProvider.overrideWithValue(dio),
        authServiceProvider.overrideWithValue(authService),
      ],
      child: const ReadlePressApp(),
    ),
  );
}

Dio _createDio() {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ),
  );
  return dio;
}

class ReadlePressApp extends ConsumerWidget {
  const ReadlePressApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'ReadlePress',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      onGenerateRoute: _generateRoute,
      home: const _AuthGate(),
    );
  }

  static ThemeData _buildTheme() {
    const seedColor = Color(0xFF1A237E);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.light,
    );

    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 2,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
      ),
      cardTheme: CardTheme(
        elevation: 0.5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.5)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        indicatorColor: colorScheme.primaryContainer,
      ),
    );
  }

  static Route<dynamic> _generateRoute(RouteSettings settings) {
    final uri = Uri.tryParse(settings.name ?? '') ?? Uri();

    switch (uri.path) {
      case '/login':
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case '/home':
        return MaterialPageRoute(builder: (_) => const HomeScreen());
      case '/students':
        return MaterialPageRoute(builder: (_) => const StudentListScreen());
      case '/capture':
        return MaterialPageRoute(
          builder: (_) => ObservationCaptureScreen(
            initialStudentId: settings.arguments as String?,
          ),
        );
      case '/rubric':
        return MaterialPageRoute(
            builder: (_) => const RubricAssessmentScreen());
      case '/dashboard':
        return MaterialPageRoute(
            builder: (_) => const MasteryDashboardScreen());
      case '/conflicts':
        return MaterialPageRoute(
            builder: (_) => const ConflictResolutionScreen());
      case '/settings':
        return MaterialPageRoute(builder: (_) => const SettingsScreen());
      default:
        if (uri.pathSegments.length == 2 &&
            uri.pathSegments[0] == 'students') {
          final id = uri.pathSegments[1];
          return MaterialPageRoute(
            builder: (_) => StudentDetailScreen(studentId: id),
          );
        }
        return MaterialPageRoute(builder: (_) => const HomeScreen());
    }
  }
}

class _AuthGate extends ConsumerWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    switch (authState.status) {
      case AuthStatus.unknown:
        return const _SplashScreen();
      case AuthStatus.authenticated:
        return const HomeScreen();
      case AuthStatus.unauthenticated:
        return const LoginScreen();
    }
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.auto_stories,
                size: 40,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'ReadlePress',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
