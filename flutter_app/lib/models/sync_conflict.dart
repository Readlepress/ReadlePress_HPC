import 'package:isar/isar.dart';

part 'sync_conflict.g.dart';

/// Isar collection for sync conflicts that need teacher resolution.
/// Created when server detects DUPLICATE, DIVERGENT, or TIMESTAMP_MISMATCH.
@collection
class SyncConflict {
  Id id = Isar.autoIncrement;

  /// References MasteryEventDraft.localId.
  late String draftLocalId;

  /// Server-assigned draft ID after sync.
  String? serverDraftId;

  /// ID of existing event that conflicts (if any).
  String? existingEventId;

  /// DUPLICATE | DIVERGENT | TIMESTAMP_MISMATCH
  late String conflictType;

  /// JSON string of device version (as sent to server).
  late String deviceVersionJson;

  /// JSON string of server version (if returned).
  String? serverVersionJson;

  /// KEEP_DEVICE | KEEP_SERVER | MERGE | DISCARD
  String? resolution;

  String? resolvedBy;
  DateTime? resolvedAt;

  late DateTime createdAt;

  SyncConflict();

  SyncConflict.create({
    required this.draftLocalId,
    this.serverDraftId,
    this.existingEventId,
    required this.conflictType,
    required this.deviceVersionJson,
    this.serverVersionJson,
    this.resolution,
    this.resolvedBy,
    this.resolvedAt,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}
