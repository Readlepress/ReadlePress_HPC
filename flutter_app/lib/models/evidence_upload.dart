import 'package:isar/isar.dart';

part 'evidence_upload.g.dart';

/// Isar collection for offline evidence uploads (photos, media).
/// Synced to /api/v1/evidence.
@collection
class EvidenceUpload {
  Id id = Isar.autoIncrement;

  /// Client-generated UUID; used for idempotency.
  late String localId;

  /// References MasteryEventDraft.localId when attached to a draft.
  String? draftId;

  /// IMAGE | VIDEO | AUDIO | DOCUMENT
  late String contentType;

  late String mimeType;

  /// Path to local file (e.g. from image_picker).
  late String localFilePath;

  int? fileSizeBytes;
  String? contentHash;

  /// PENDING | UPLOADING | UPLOADED | FAILED
  late String uploadStatus;

  String? uploadError;

  EvidenceUpload();

  EvidenceUpload.create({
    required this.localId,
    this.draftId,
    required this.contentType,
    required this.mimeType,
    required this.localFilePath,
    this.fileSizeBytes,
    this.contentHash,
    this.uploadStatus = 'PENDING',
    this.uploadError,
  });
}
