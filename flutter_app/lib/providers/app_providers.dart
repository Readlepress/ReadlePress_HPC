import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';

import '../config/api_config.dart';
import '../models/competency.dart';
import '../models/evidence_upload.dart';
import '../models/mastery_event_draft.dart';
import '../models/student.dart';
import '../models/sync_conflict.dart';
import '../services/auth_service.dart';
import '../services/capture_service.dart';
import '../services/gps_timestamp_service.dart';
import '../services/sync_service.dart';

// ── Base providers (overridden in main.dart) ──

final isarProvider = Provider<Isar>((ref) => throw UnimplementedError());
final apiConfigProvider =
    Provider<ApiConfig>((ref) => throw UnimplementedError());
final dioProvider = Provider<Dio>((ref) => throw UnimplementedError());
final authServiceProvider =
    Provider<AuthService>((ref) => throw UnimplementedError());

// ── Derived service providers ──

final gpsTimestampServiceProvider = Provider<GpsTimestampService>((ref) {
  return GpsTimestampService();
});

final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(
    isar: ref.read(isarProvider),
    dio: ref.read(dioProvider),
    apiConfig: ref.read(apiConfigProvider),
    authService: ref.read(authServiceProvider),
  );
});

final captureServiceProvider = Provider<CaptureService>((ref) {
  return CaptureService(
    isar: ref.read(isarProvider),
    gpsTimestampService: ref.read(gpsTimestampServiceProvider),
    syncService: ref.read(syncServiceProvider),
  );
});

// ── Auth state ──

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.error,
    this.isLoading = false,
  });

  final AuthStatus status;
  final Map<String, dynamic>? user;
  final String? error;
  final bool isLoading;

  String get teacherName =>
      user?['name'] as String? ??
      user?['fullName'] as String? ??
      'Teacher';
  String get schoolName =>
      user?['schoolName'] as String? ??
      user?['school'] as String? ??
      '';
  String get userId =>
      user?['userId'] as String? ?? user?['id'] as String? ?? '';
  String get role => user?['role'] as String? ?? 'TEACHER';
  String get classSection =>
      user?['classSection'] as String? ??
      user?['class'] as String? ??
      '';
  String get stage =>
      user?['stage'] as String? ?? 'FOUNDATIONAL';

  AuthState copyWith({
    AuthStatus? status,
    Map<String, dynamic>? user,
    String? error,
    bool? isLoading,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      error: error,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class AuthStateNotifier extends StateNotifier<AuthState> {
  AuthStateNotifier(this._authService) : super(const AuthState()) {
    _checkAuth();
  }

  final AuthService _authService;

  Future<void> _checkAuth() async {
    final loggedIn = await _authService.isLoggedIn();
    if (loggedIn) {
      final user = await _authService.getStoredUser();
      state = AuthState(status: AuthStatus.authenticated, user: user);
    } else {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> login({
    String? email,
    String? phone,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _authService.login(email: email, phone: phone, password: password);
      final user = await _authService.getStoredUser();
      state = AuthState(status: AuthStatus.authenticated, user: user);
    } on AuthException catch (e) {
      state = AuthState(
        status: AuthStatus.unauthenticated,
        error: e.message,
      );
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] as String? ??
          e.message ??
          'Network error';
      state = AuthState(status: AuthStatus.unauthenticated, error: msg);
    } catch (e) {
      state = AuthState(
        status: AuthStatus.unauthenticated,
        error: e.toString(),
      );
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

final authStateProvider =
    StateNotifierProvider<AuthStateNotifier, AuthState>((ref) {
  return AuthStateNotifier(ref.read(authServiceProvider));
});

// ── Connectivity ──

final connectivityProvider = StreamProvider<bool>((ref) {
  return Connectivity().onConnectivityChanged.map((result) {
    return result == ConnectivityResult.mobile ||
        result == ConnectivityResult.wifi ||
        result == ConnectivityResult.ethernet;
  });
});

// ── Sync status ──

class SyncStatus {
  const SyncStatus({
    this.pendingDrafts = 0,
    this.pendingEvidence = 0,
    this.failedDrafts = 0,
    this.conflictCount = 0,
    this.lastSyncTime,
    this.isSyncing = false,
    this.lastError,
  });

  final int pendingDrafts;
  final int pendingEvidence;
  final int failedDrafts;
  final int conflictCount;
  final DateTime? lastSyncTime;
  final bool isSyncing;
  final String? lastError;

  int get totalPending => pendingDrafts + pendingEvidence;
  bool get hasErrors => failedDrafts > 0 || lastError != null;
}

final syncStatusProvider = FutureProvider<SyncStatus>((ref) async {
  final isar = ref.read(isarProvider);

  final pendingDrafts = await isar.masteryEventDrafts
      .filter()
      .syncStatusEqualTo('PENDING')
      .count();
  final failedDrafts = await isar.masteryEventDrafts
      .filter()
      .syncStatusEqualTo('FAILED')
      .count();
  final pendingEvidence = await isar.evidenceUploads
      .filter()
      .uploadStatusEqualTo('PENDING')
      .count();
  final conflictCount = await isar.syncConflicts
      .filter()
      .resolutionIsNull()
      .count();

  return SyncStatus(
    pendingDrafts: pendingDrafts,
    pendingEvidence: pendingEvidence,
    failedDrafts: failedDrafts,
    conflictCount: conflictCount,
  );
});

// ── Students ──

final studentsProvider = FutureProvider<List<Student>>((ref) async {
  final dio = ref.read(dioProvider);
  final apiConfig = ref.read(apiConfigProvider);
  try {
    final response =
        await dio.get<Map<String, dynamic>>(apiConfig.students);
    final data = response.data;
    if (data != null) {
      final list = data['students'] as List<dynamic>? ??
          data['data'] as List<dynamic>? ??
          [];
      return list
          .map((s) => Student.fromJson(s as Map<String, dynamic>))
          .toList();
    }
  } on DioException {
    // Offline or server error — return empty list
  }
  return [];
});

// ── Domains & competencies ──

final domainsProvider = FutureProvider<List<Domain>>((ref) async {
  final dio = ref.read(dioProvider);
  final apiConfig = ref.read(apiConfigProvider);
  try {
    final response =
        await dio.get<Map<String, dynamic>>(apiConfig.competencies);
    final data = response.data;
    if (data != null) {
      final list = data['domains'] as List<dynamic>? ??
          data['data'] as List<dynamic>? ??
          [];
      return list
          .map((d) => Domain.fromJson(d as Map<String, dynamic>))
          .toList();
    }
  } on DioException {
    // Offline or server error
  }
  return [];
});

// ── All mastery event drafts ──

final allDraftsProvider = FutureProvider<List<MasteryEventDraft>>((ref) async {
  final isar = ref.read(isarProvider);
  return isar.masteryEventDrafts.where().findAll();
});

// ── Unresolved sync conflicts ──

final unresolvedConflictsProvider =
    FutureProvider<List<SyncConflict>>((ref) async {
  final isar = ref.read(isarProvider);
  return isar.syncConflicts.filter().resolutionIsNull().findAll();
});

// ── Pending evidence uploads ──

final pendingEvidenceProvider =
    FutureProvider<List<EvidenceUpload>>((ref) async {
  final isar = ref.read(isarProvider);
  return isar.evidenceUploads
      .filter()
      .uploadStatusEqualTo('PENDING')
      .findAll();
});
