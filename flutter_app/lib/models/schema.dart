/// Exports all Isar schemas for database initialization.
/// Run `dart run build_runner build --delete-conflicting-outputs` to generate.
import 'package:isar/isar.dart';

import 'mastery_event_draft.dart';
import 'evidence_upload.dart';
import 'sync_conflict.dart';

/// List of all collection schemas for Isar.open().
List<CollectionSchema<dynamic>> get allSchemas => [
      MasteryEventDraftSchema,
      EvidenceUploadSchema,
      SyncConflictSchema,
    ];
