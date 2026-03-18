import 'dart:io';

import 'package:isar/isar.dart';
import 'package:uuid/uuid.dart';

import '../models/evidence_upload.dart';
import '../models/mastery_event_draft.dart';
import 'gps_timestamp_service.dart';
import 'sync_service.dart';

/// Teacher observation capture service.
/// Creates mastery_event_draft in local Isar DB, attaches evidence,
/// uses GPS timestamp service, queues for background sync.
class CaptureService {
  CaptureService({
    required this.isar,
    required this.gpsTimestampService,
    required this.syncService,
    this.deviceId,
  });

  final Isar isar;
  final GpsTimestampService gpsTimestampService;
  final SyncService syncService;
  final String? deviceId;

  final _uuid = const Uuid();

  /// Create a mastery event draft from teacher observation.
  /// Uses GPS timestamp service for accurate timestamps.
  Future<MasteryEventDraft> captureObservation({
    required String studentId,
    required String competencyId,
    required double numericValue,
    String? descriptorLevelId,
    String? observationNote,
    List<String> evidenceLocalIds = const [],
    String sourceType = 'DIRECT_OBSERVATION',
  }) async {
    final timestampResult = await gpsTimestampService.getTimestamp();

    final draft = MasteryEventDraft.create(
      localId: _uuid.v4(),
      studentId: studentId,
      competencyId: competencyId,
      observedAt: timestampResult.timestamp,
      recordedAt: DateTime.now(),
      timestampSource: timestampResult.timestampSource,
      timestampConfidence: timestampResult.timestampConfidence,
      numericValue: numericValue,
      descriptorLevelId: descriptorLevelId,
      observationNote: observationNote,
      evidenceLocalIds: List.from(evidenceLocalIds),
      sourceType: sourceType,
      syncStatus: 'PENDING',
      deviceId: deviceId,
    );

    await isar.writeTxn(() async {
      await isar.masteryEventDrafts.put(draft);
    });

    return draft;
  }

  /// Attach evidence (e.g. photo) to a draft.
  /// Copies or references the file and creates EvidenceUpload record.
  Future<EvidenceUpload> attachEvidence({
    required String draftLocalId,
    required String localFilePath,
    required String contentType,
    required String mimeType,
    int? fileSizeBytes,
    String? contentHash,
  }) async {
    final file = File(localFilePath);
    if (!await file.exists()) {
      throw CaptureException('File not found: $localFilePath');
    }

    final size = fileSizeBytes ?? await file.length();
    final localId = _uuid.v4();

    final evidence = EvidenceUpload.create(
      localId: localId,
      draftId: draftLocalId,
      contentType: contentType,
      mimeType: mimeType,
      localFilePath: localFilePath,
      fileSizeBytes: size,
      contentHash: contentHash,
      uploadStatus: 'PENDING',
    );

    await isar.writeTxn(() async {
      await isar.evidenceUploads.put(evidence);

      final draft = await isar.masteryEventDrafts
          .filter()
          .localIdEqualTo(draftLocalId)
          .findFirst();

      if (draft != null) {
        draft.evidenceLocalIds = [...draft.evidenceLocalIds, localId];
        await isar.masteryEventDrafts.put(draft);
      }
    });

    return evidence;
  }

  /// Get all pending drafts (for sync or display).
  Future<List<MasteryEventDraft>> getPendingDrafts() async {
    return isar.masteryEventDrafts
        .filter()
        .syncStatusEqualTo('PENDING')
        .findAll();
  }

  /// Trigger background sync via WorkManager.
  /// Call after capturing to queue sync when online.
  void queueBackgroundSync() {
    // WorkManager will be configured in main.dart to call sync
    // This is a placeholder - actual WorkManager registration
    // happens at app init. The capture service just needs to
    // ensure data is persisted; WorkManager periodic task handles sync.
  }
}

class CaptureException implements Exception {
  CaptureException(this.message);
  final String message;
  @override
  String toString() => 'CaptureException: $message';
}
