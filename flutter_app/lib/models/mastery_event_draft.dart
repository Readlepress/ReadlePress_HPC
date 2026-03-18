import 'package:isar/isar.dart';

part 'mastery_event_draft.g.dart';

/// Isar collection for offline mastery event drafts.
/// Queued locally and synced to /api/v1/capture/sync.
@collection
class MasteryEventDraft {
  Id id = Isar.autoIncrement;

  /// Client-generated UUID; used for idempotency on sync.
  late String localId;

  late String studentId;
  late String competencyId;

  /// When the observation occurred (preserved exactly, never overwritten by server).
  late DateTime observedAt;

  /// When the teacher recorded the observation on device.
  late DateTime recordedAt;

  /// Source of the timestamp per GPS timestamp spec.
  late String timestampSource; // GPS_FIX | GPS_OFFSET | NTP_SYNCED | DEVICE_CLOCK

  /// Confidence level of the timestamp.
  late String timestampConfidence; // HIGH | MEDIUM | LOW

  /// Mastery value 0.0–1.0.
  late double numericValue;

  String? descriptorLevelId;
  String? observationNote;

  /// Local IDs of attached evidence (references EvidenceUpload.localId).
  List<String> evidenceLocalIds = [];

  /// DIRECT_OBSERVATION | SELF_ASSESSMENT | PEER_ASSESSMENT | HISTORICAL_ENTRY
  late String sourceType;

  /// PENDING | SYNCING | SYNCED | CONFLICT | FAILED
  late String syncStatus;

  String? syncError;
  String? deviceId;

  MasteryEventDraft();

  MasteryEventDraft.create({
    required this.localId,
    required this.studentId,
    required this.competencyId,
    required this.observedAt,
    required this.recordedAt,
    required this.timestampSource,
    required this.timestampConfidence,
    required this.numericValue,
    this.descriptorLevelId,
    this.observationNote,
    List<String>? evidenceLocalIds,
    this.sourceType = 'DIRECT_OBSERVATION',
    this.syncStatus = 'PENDING',
    this.syncError,
    this.deviceId,
  }) : evidenceLocalIds = evidenceLocalIds ?? [];
}
