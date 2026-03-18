import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:isar/isar.dart';
import 'package:path/path.dart' as path;

import '../config/api_config.dart';
import '../models/evidence_upload.dart';
import '../models/mastery_event_draft.dart';
import '../models/sync_conflict.dart';
import 'auth_service.dart';

/// Core offline sync service.
/// Preserves observed_at exactly as captured (never overwrites with server time).
/// Idempotent: same local_id not re-uploaded.
class SyncService {
  SyncService({
    required this.isar,
    required this.dio,
    required this.apiConfig,
    required this.authService,
  });

  final Isar isar;
  final Dio dio;
  final ApiConfig apiConfig;
  final AuthService authService;

  static const _maxRetries = 3;
  static const _retryDelayMs = 2000;

  /// Check if device has network connectivity.
  Future<bool> get isOnline async {
    final result = await Connectivity().checkConnectivity();
    return result == ConnectivityResult.mobile ||
        result == ConnectivityResult.wifi ||
        result == ConnectivityResult.ethernet;
  }

  /// Sync pending mastery event drafts to /api/v1/capture/sync.
  /// Idempotent: skips drafts already synced (by localId).
  Future<SyncDraftsResult> syncPendingDrafts({
    required String teacherId,
    String? deviceId,
  }) async {
    if (!await isOnline) {
      return SyncDraftsResult(offline: true, synced: 0, conflicts: 0, failed: 0);
    }

    final drafts = await isar.masteryEventDrafts
        .filter()
        .syncStatusEqualTo('PENDING')
        .findAll();

    if (drafts.isEmpty) {
      return SyncDraftsResult(offline: false, synced: 0, conflicts: 0, failed: 0);
    }

    final user = await authService.getStoredUser();
    final teacherIdToUse = teacherId;

    final payload = drafts.map((d) => _draftToSyncPayload(d, deviceId)).toList();

    try {
      final response = await dio.post<Map<String, dynamic>>(
        apiConfig.captureSync,
        data: {
          'teacherId': teacherIdToUse,
          'drafts': payload,
        },
      );

      final data = response.data;
      if (data == null) {
        return _markDraftsFailed(drafts, 'Empty response');
      }

      final results = data['results'] as List<dynamic>? ?? [];
      int synced = 0, conflicts = 0, failed = 0;

      for (var i = 0; i < results.length && i < drafts.length; i++) {
        final r = results[i] as Map<String, dynamic>? ?? {};
        final status = r['status'] as String? ?? 'FAILED';
        final draftId = r['draftId'] as String?;
        final localId = r['localId'] as String? ?? drafts[i].localId;

        await isar.writeTxn(() async {
          final draft = drafts[i];
          switch (status) {
            case 'ALREADY_SYNCED':
            case 'SYNCED':
              draft.syncStatus = 'SYNCED';
              draft.syncError = null;
              synced++;
              break;
            case 'CONFLICT':
              draft.syncStatus = 'CONFLICT';
              draft.syncError = null;
              conflicts++;
              if (draftId != null) {
                final conflict = SyncConflict.create(
                  draftLocalId: localId,
                  serverDraftId: draftId,
                  conflictType: 'DIVERGENT',
                  deviceVersionJson: jsonEncode(_draftToSyncPayload(draft, deviceId)),
                );
                await isar.syncConflicts.put(conflict);
              }
              break;
            default:
              draft.syncStatus = 'FAILED';
              draft.syncError = r['reason'] as String? ?? status;
              failed++;
          }
          await isar.masteryEventDrafts.put(draft);
        });
      }

      return SyncDraftsResult(
        offline: false,
        synced: synced,
        conflicts: conflicts,
        failed: failed,
      );
    } on DioException catch (e) {
      return _markDraftsFailed(drafts, e.message ?? 'Network error');
    } catch (e) {
      return _markDraftsFailed(drafts, e.toString());
    }
  }

  Map<String, dynamic> _draftToSyncPayload(
    MasteryEventDraft d,
    String? deviceId,
  ) {
    return {
      'localId': d.localId,
      'studentId': d.studentId,
      'competencyId': d.competencyId,
      'observedAt': d.observedAt.toIso8601String(),
      'recordedAt': d.recordedAt.toIso8601String(),
      'timestampSource': d.timestampSource,
      'timestampConfidence': d.timestampConfidence,
      'numericValue': d.numericValue,
      if (d.descriptorLevelId != null) 'descriptorLevelId': d.descriptorLevelId,
      if (d.observationNote != null) 'observationNote': d.observationNote,
      if (d.evidenceLocalIds.isNotEmpty) 'evidenceLocalIds': d.evidenceLocalIds,
      'sourceType': d.sourceType,
      if (deviceId != null) 'deviceId': deviceId,
    };
  }

  Future<SyncDraftsResult> _markDraftsFailed(
    List<MasteryEventDraft> drafts,
    String error,
  ) async {
    await isar.writeTxn(() async {
      for (final d in drafts) {
        d.syncStatus = 'FAILED';
        d.syncError = error;
        await isar.masteryEventDrafts.put(d);
      }
    });
    return SyncDraftsResult(
      offline: false,
      synced: 0,
      conflicts: 0,
      failed: drafts.length,
    );
  }

  /// Sync pending evidence to /api/v1/evidence.
  /// Evidence must be uploaded before drafts that reference it.
  Future<SyncEvidenceResult> syncPendingEvidence({
    required String storageProviderId,
    String? deviceId,
  }) async {
    if (!await isOnline) {
      return SyncEvidenceResult(offline: true, uploaded: 0, failed: 0);
    }

    final pending = await isar.evidenceUploads
        .filter()
        .uploadStatusEqualTo('PENDING')
        .findAll();

    if (pending.isEmpty) {
      return SyncEvidenceResult(offline: false, uploaded: 0, failed: 0);
    }

    int uploaded = 0, failed = 0;

    for (final ev in pending) {
      final file = File(ev.localFilePath);
      if (!await file.exists()) {
        await _markEvidenceFailed(ev, 'File not found');
        failed++;
        continue;
      }

      ev.uploadStatus = 'UPLOADING';
      await isar.evidenceUploads.put(ev);

      try {
        final bytes = await file.readAsBytes();
        final contentRef = '${storageProviderId}/${ev.localId}';
        final mimeType = ev.mimeType;
        final ext = path.extension(ev.localFilePath).toLowerCase();
        final originalFilename = 'evidence_${ev.localId}$ext';

        final response = await dio.post<Map<String, dynamic>>(
          apiConfig.evidence,
          data: {
            'storageProviderId': storageProviderId,
            'contentRef': contentRef,
            'contentType': ev.contentType,
            'mimeType': mimeType,
            'fileSizeBytes': ev.fileSizeBytes ?? bytes.length,
            'originalFilename': originalFilename,
            'contentHash': ev.contentHash ?? _simpleHash(bytes),
            'trustLevel': 'TEACHER_DIRECT',
          },
          options: Options(
            contentType: 'application/json',
            // If server expects multipart, this would need to change
          ),
        );

        if (response.statusCode == 201 && response.data != null) {
          ev.uploadStatus = 'UPLOADED';
          ev.uploadError = null;
          await isar.evidenceUploads.put(ev);
          uploaded++;
        } else {
          await _markEvidenceFailed(ev, 'Unexpected response');
          failed++;
        }
      } catch (e) {
        await _markEvidenceFailed(ev, e.toString());
        failed++;
      }
    }

    return SyncEvidenceResult(
      offline: false,
      uploaded: uploaded,
      failed: failed,
    );
  }

  String _simpleHash(List<int> bytes) {
    var h = 0;
    for (final b in bytes) {
      h = ((h << 5) - h + b) & 0xFFFFFFFF;
    }
    return h.toRadixString(16);
  }

  Future<void> _markEvidenceFailed(EvidenceUpload ev, String error) async {
    ev.uploadStatus = 'FAILED';
    ev.uploadError = error;
    await isar.evidenceUploads.put(ev);
  }

  /// Resolve a sync conflict (UI-driven).
  /// resolution: KEEP_DEVICE | KEEP_SERVER | MERGE | DISCARD
  Future<void> resolveConflicts({
    required String draftLocalId,
    required String resolution,
    required String resolvedBy,
  }) async {
    final conflicts = await isar.syncConflicts
        .filter()
        .draftLocalIdEqualTo(draftLocalId)
        .findAll();

    await isar.writeTxn(() async {
      for (final c in conflicts) {
        c.resolution = resolution;
        c.resolvedBy = resolvedBy;
        c.resolvedAt = DateTime.now();
        await isar.syncConflicts.put(c);
      }

      final draft = await isar.masteryEventDrafts
          .filter()
          .localIdEqualTo(draftLocalId)
          .findFirst();

      if (draft != null) {
        if (resolution == 'DISCARD') {
          await isar.masteryEventDrafts.delete(draft.id);
        } else {
          draft.syncStatus = 'SYNCED';
          draft.syncError = null;
          await isar.masteryEventDrafts.put(draft);
        }
      }
    });
  }
}

class SyncDraftsResult {
  SyncDraftsResult({
    required this.offline,
    required this.synced,
    required this.conflicts,
    required this.failed,
  });

  final bool offline;
  final int synced;
  final int conflicts;
  final int failed;
}

class SyncEvidenceResult {
  SyncEvidenceResult({
    required this.offline,
    required this.uploaded,
    required this.failed,
  });

  final bool offline;
  final int uploaded;
  final int failed;
}
