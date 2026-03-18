import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:workmanager/workmanager.dart';

import 'config/api_config.dart';
import 'models/schema.dart';
import 'services/auth_service.dart';
import 'widgets/observation_form.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    // Background sync task - would need access to Isar, Dio, etc.
    // For now, this is a placeholder. Full implementation would
    // initialize services in the isolate or use a different approach.
    return true;
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Isar (run build_runner first to generate schemas)
  final dir = await getApplicationDocumentsDirectory();
  final isar = await Isar.open(
    allSchemas,
    directory: dir.path,
  );

  // Initialize WorkManager for background sync
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

  // API and auth setup
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

final isarProvider = Provider<Isar>((ref) => throw UnimplementedError());
final apiConfigProvider = Provider<ApiConfig>((ref) => throw UnimplementedError());
final dioProvider = Provider<Dio>((ref) => throw UnimplementedError());
final authServiceProvider = Provider<AuthService>((ref) => throw UnimplementedError());

class ReadlePressApp extends StatelessWidget {
  const ReadlePressApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ReadlePress',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const ObservationForm(),
    );
  }
}
